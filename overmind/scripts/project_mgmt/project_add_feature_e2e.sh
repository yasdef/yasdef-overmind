#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
STATE_FILE_NAME=".project_add_feature_e2e_state.env"
FIRST_SUPPORTED_STEP="3"
MODELS_FILE=".setup/models.md"
TASK_TO_BR_MODEL_PHASE="task_to_br"
TASK_TO_BR_SKILL_FILE=".codex/skills/overmind-task-to-br/SKILL.md"
BR_CLARIFICATION_MODEL_PHASE="user_br_clarification"
BR_CLARIFICATION_SKILL_FILE=".codex/skills/overmind-br-clarification/SKILL.md"
REQUIREMENTS_EARS_MODEL_PHASE="br_to_ears"
REQUIREMENTS_EARS_SKILL_FILE=".codex/skills/overmind-requirements-ears/SKILL.md"
EARS_REVIEW_MODEL_PHASE="requirements_ears_review"
EARS_REVIEW_SKILL_FILE=".codex/skills/overmind-ears-review/SKILL.md"
CONTRACT_DELTA_MODEL_PHASE="feature_contract_delta"
CONTRACT_DELTA_SKILL_FILE=".codex/skills/overmind-contract-delta/SKILL.md"
SURFACE_MAP_MODEL_PHASE="feature_repo_surface_and_exec_context"
SURFACE_MAP_SKILL_FILE=".codex/skills/overmind-surface-map/SKILL.md"
SURFACE_MAP_ENRICH_MODEL_PHASE="feature_surface_map_mcp_placeholder_enrichment"
SURFACE_MAP_ENRICH_SKILL_FILE=".codex/skills/overmind-surface-map-enrich/SKILL.md"
TECHNICAL_REQUIREMENTS_MODEL_PHASE="feature_technical_requirements"
TECHNICAL_REQUIREMENTS_SKILL_FILE=".codex/skills/overmind-technical-requirements/SKILL.md"
IMPLEMENTATION_SLICES_MODEL_PHASE="repository_implementation_slices"
IMPLEMENTATION_SLICES_SKILL_FILE=".codex/skills/overmind-implementation-slices/SKILL.md"
PREREQUISITE_GAPS_MODEL_PHASE="prerequisite_gap_trace"
PREREQUISITE_GAPS_SKILL_FILE=".codex/skills/overmind-prerequisite-gaps/SKILL.md"
IMPLEMENTATION_PLAN_MODEL_PHASE="repository_implementation_plan"
IMPLEMENTATION_PLAN_SKILL_FILE=".codex/skills/overmind-implementation-plan/SKILL.md"
PLAN_SEMANTIC_REVIEW_MODEL_PHASE="implementation_plan_semantic_review"
PLAN_SEMANTIC_REVIEW_SKILL_FILE=".codex/skills/overmind-plan-semantic-review/SKILL.md"
REPO_BR_SCAN_MODEL_PHASE="repo_analyse"
REPO_BR_SCAN_SKILL_FILE=".codex/skills/overmind-repo-br-scan/SKILL.md"
OVERMIND_CLI_FILE=".overmind/overmind.js"
TARGET_PATH_INPUT=""
RESUME_STEP_INPUT=""
RUNTIME_ROOT=""
PROJECT_PATH=""
PROJECT_ROOT=""
STATE_FILE=""
FEATURE_PATH=""
PROJECT_TYPE_CODE=""
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
DISCOVERED_PROJECT_PATHS=()
DISCOVERED_PROJECT_NAMES=()
RECONCILIATION_TRANSACTION_STARTED="false"
RECONCILIATION_RAN="false"
RECONCILED_CLASSES_THIS_RUN=()
SCANNER_NEXT_STEP_INFO=""
MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()

PHASE_IDS=("3" "4.1" "4.2" "5" "5.1" "6" "7" "7.1" "8" "8.1" "8.2" "8.3" "8.4")
PHASE_OPTIONAL=("false" "false" "false" "false" "true" "false" "false" "true" "false" "false" "false" "false" "true")


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

print_usage() {
  cat <<'USAGE'
Usage: project_add_feature_e2e.sh [--path <project-folder-path>] [--resume <step>]

Options:
  --path <project-folder-path>  Optional ASDLC project folder (for example: projects/<project-id>)
  --resume <step>               Optional step override (for example: 3, 4.1, 4.2, 5, 5.1, 6, 7, 7.1 (optional MCP placeholder enrichment), 8, 8.1, 8.2 (prerequisite gap trace), 8.3 (implementation plan), 8.4 (optional semantic review))
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

  printf '%s' "$parent_dir"
}

resolve_projects_root() {
  local runtime_root="$1"
  local projects_root="$runtime_root/projects"

  if [[ ! -d "$projects_root" ]]; then
    die "Required directory not found: $projects_root"
  fi

  if ! projects_root="$(cd "$projects_root" && pwd -P)"; then
    die "Failed to resolve ASDLC projects directory: $runtime_root/projects"
  fi

  printf '%s' "$projects_root"
}

discover_projects() {
  local runtime_root="$1"
  local projects_root="$2"
  local child_path=""
  local resolved_path=""
  local rel_path=""

  DISCOVERED_PROJECT_PATHS=()
  DISCOVERED_PROJECT_NAMES=()

  while IFS= read -r child_path; do
    [[ -n "$child_path" ]] || continue
    [[ -f "$child_path/init_progress_definition.yaml" ]] || continue

    if ! resolved_path="$(cd "$child_path" && pwd -P)"; then
      die "Failed to resolve project path: $child_path"
    fi

    rel_path="${resolved_path#"$runtime_root/"}"
    DISCOVERED_PROJECT_PATHS+=("$rel_path")
    DISCOVERED_PROJECT_NAMES+=("$(basename "$resolved_path")")
  done < <(find "$projects_root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | LC_ALL=C sort)
}

prompt_project_selection() {
  local answer=""
  local idx=0
  local total="${#DISCOVERED_PROJECT_PATHS[@]}"

  [[ "$total" -gt 1 ]] || return 1

  echo "No --path provided. Multiple projects found under ASDLC projects:"
  for ((idx = 0; idx < total; idx++)); do
    printf '  %s) %s [%s]\n' "$((idx + 1))" "${DISCOVERED_PROJECT_NAMES[$idx]}" "${DISCOVERED_PROJECT_PATHS[$idx]}"
  done
  echo "  q) Finish without running project_add_feature_e2e.sh"

  while true; do
    printf 'Choose project [1-%s] or q to finish: ' "$total" >&2
    if ! IFS= read -r answer; then
      return 2
    fi

    answer="$(to_lower "$(trim_value "$answer")")"
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= total )); then
      TARGET_PATH_INPUT="${DISCOVERED_PROJECT_PATHS[$((answer - 1))]}"
      echo "Selected project: $TARGET_PATH_INPUT"
      return 0
    fi

    case "$answer" in
      q|quit|exit|finish|stop)
        return 1
        ;;
      *)
        echo "Please answer with a number between 1 and $total, or q to finish." >&2
        ;;
    esac
  done
}

auto_select_project_path() {
  local runtime_root="$1"
  local projects_root=""
  local project_count=0
  local selection_rc=0

  projects_root="$(resolve_projects_root "$runtime_root")"
  discover_projects "$runtime_root" "$projects_root"
  project_count="${#DISCOVERED_PROJECT_PATHS[@]}"

  if [[ "$project_count" -eq 0 ]]; then
    die "No project folders containing init_progress_definition.yaml were found under: $projects_root"
  fi

  if [[ "$project_count" -eq 1 ]]; then
    TARGET_PATH_INPUT="${DISCOVERED_PROJECT_PATHS[0]}"
    echo "No --path provided. Found one ASDLC project; using path: $TARGET_PATH_INPUT"
    return 0
  fi

  prompt_project_selection
  selection_rc=$?

  case "$selection_rc" in
    0)
      return 0
      ;;
    1)
      echo "Execution finished: no project selected."
      return 20
      ;;
    2)
      echo "Execution stopped: user input stream closed during project selection."
      return 20
      ;;
    *)
      die "Unexpected project selection status: $selection_rc"
      ;;
  esac
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

extract_project_type_code_from_definition() {
  local definition_path="$1"

  [[ -f "$definition_path" ]] || return 0

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

  if ($0 ~ /^[[:space:]]{2}project_type_code:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{2}project_type_code:[[:space:]]*/, "", line)
    print strip_quotes(line)
    exit 0
  }
}
' "$definition_path"
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
    7) printf '%s' "Analyze Repos And Prepare Repo Execution Context" ;;
    7.1) printf '%s' "Optional MCP Placeholder Enrichment" ;;
    8) printf '%s' "Create Feature-Scoped Technical Requirements" ;;
    8.1) printf '%s' "Implementation Slices" ;;
    8.2) printf '%s' "Prerequisite Gap Trace" ;;
    8.3) printf '%s' "Implementation Plan" ;;
    8.4) printf '%s' "Optional Implementation Plan Semantic Review" ;;
    *) printf '%s' "$1" ;;
  esac
}

commit_feature_progress() {
  local label="$1"
  local commit_message="Checkpoint: $label"
  local git_rc=0

  if ! command -v git >/dev/null 2>&1; then
    echo "Checkpoint commit skipped ($label): git not found in PATH."
    return 0
  fi

  if ! git -C "$RUNTIME_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Checkpoint commit skipped ($label): runtime root is not a git repository."
    return 0
  fi

  if ! git -C "$RUNTIME_ROOT" add -A >/dev/null 2>&1; then
    git_rc=$?
    echo "Checkpoint commit notice ($label): git add exited $git_rc; continuing without checkpoint."
    return 0
  fi

  set +e
  git -C "$RUNTIME_ROOT" commit -m "$commit_message" >/dev/null 2>&1
  git_rc=$?
  set -e

  if [[ "$git_rc" -ne 0 ]]; then
    echo "Checkpoint commit notice ($label): git commit exited $git_rc; continuing without checkpoint."
    return 0
  fi

  echo "Checkpoint commit created: $commit_message"
  return 0
}

load_model_config() {
  local models_path="$1"
  local phase="$2"
  local fields=()
  local field=""

  if [[ ! -f "$models_path" ]]; then
    die "Models file not found: $MODELS_FILE"
  fi

  while IFS= read -r field; do
    fields+=("$field")
  done < <(
    awk -F'|' -v phase="$phase" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      /^[[:space:]]*#/ { next }
      NF < 3 { next }
      {
        key = trim($1)
        cmd = trim($2)
        model = trim($3)
        if (tolower(key) == tolower(phase)) {
          print cmd
          print model
          for (i = 4; i <= NF; i++) {
            arg = trim($i)
            if (arg != "") { print arg }
          }
          exit
        }
      }
    ' "$models_path"
  )

  if [[ ${#fields[@]} -lt 2 || -z "${fields[0]}" || -z "${fields[1]}" ]]; then
    die "Invalid or missing '$phase' entry in $MODELS_FILE (expected: $phase | codex | <model> | <args... optional>)"
  fi

  MODEL_CMD="${fields[0]}"
  MODEL_MODEL="${fields[1]}"
  MODEL_ARGS=()
  if [[ ${#fields[@]} -gt 2 ]]; then
    MODEL_ARGS=("${fields[@]:2}")
  fi
}

build_task_to_br_prompt() {
  local runtime_root="$1"
  local feature_br_file="$FEATURE_PATH/feature_br_summary.md"
  local user_input_file="$FEATURE_PATH/user_br_input.md"
  local missing_data_file="$FEATURE_PATH/missing_br_data.md"

  cat <<EOF
Use the overmind-task-to-br skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Feature BR summary artifact: $feature_br_file
- Captured user input artifact: $user_input_file
- Missing-data artifact: $missing_data_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-task-to-br skill.
- If $user_input_file is missing, ask the operator for exactly one source: either a local .txt/.md source file inside the feature folder, or a Jira ticket.
- If $user_input_file already exists, do not ask for a new source unless the skill requires recovery.
- Use exactly one capture command only when capture is needed:
  node $OVERMIND_CLI_FILE capture task-to-br $FEATURE_PATH --source-file <path-to-story.md-or.txt>
  node $OVERMIND_CLI_FILE capture task-to-br $FEATURE_PATH --jira <ticket>
- Then assemble deterministic context with:
  node $OVERMIND_CLI_FILE context task-to-br $FEATURE_PATH
- Update only the artifacts allowed by the skill.
- Validate after every write or repair with:
  node $OVERMIND_CLI_FILE gate task-to-br $FEATURE_PATH
- Handle gate exit codes exactly as the skill defines.
EOF
}

run_task_to_br_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_br_file="$runtime_root/$FEATURE_PATH/feature_br_summary.md"
  local user_input_file="$runtime_root/$FEATURE_PATH/user_br_input.md"
  local missing_data_file="$runtime_root/$FEATURE_PATH/missing_br_data.md"
  local prompt_arg=""
  local model_rc=0

  [[ -f "$feature_br_file" ]] || die "Required file not found: $FEATURE_PATH/feature_br_summary.md"
  [[ -f "$runtime_root/$TASK_TO_BR_SKILL_FILE" ]] || die "Required skill not found: $TASK_TO_BR_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  load_model_config "$models_path" "$TASK_TO_BR_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$TASK_TO_BR_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_task_to_br_prompt "$runtime_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi

  [[ -f "$user_input_file" ]] || die "Task-to-BR model run did not produce required file: $FEATURE_PATH/user_br_input.md"
  [[ -f "$missing_data_file" ]] || die "Task-to-BR model run did not produce required file: $FEATURE_PATH/missing_br_data.md"

  echo "Updated $FEATURE_PATH/user_br_input.md"
  echo "Updated $FEATURE_PATH/missing_br_data.md"
}

build_repo_br_scan_prompt() {
  local runtime_root="$1"
  local feature_br_file="$FEATURE_PATH/feature_br_summary.md"

  cat <<EOF
Load and follow the overmind-repo-br-scan skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Feature BR summary artifact: $feature_br_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-repo-br-scan skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context repo-br-scan $FEATURE_PATH
- Follow the skill's instructions exactly.
- Validate after every write or repair with:
  node $OVERMIND_CLI_FILE gate repo-br-scan $FEATURE_PATH
- Handle gate exit codes as defined in the skill.
EOF
}

run_repo_br_scan_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_br_file="$runtime_root/$FEATURE_PATH/feature_br_summary.md"
  local prompt_arg=""
  local model_rc=0
  local sync_rc=0

  [[ -f "$feature_br_file" ]] || die "Required file not found: $FEATURE_PATH/feature_br_summary.md"
  [[ -f "$runtime_root/$REPO_BR_SCAN_SKILL_FILE" ]] || die "Required skill not found: $REPO_BR_SCAN_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  (cd "$runtime_root" && node "$OVERMIND_CLI_FILE" sync repo-br-scan "$FEATURE_PATH")
  sync_rc=$?
  set -e
  if [[ "$sync_rc" -ne 0 ]]; then
    echo "Execution stopped: phase 4.1 repo sync failed (exit $sync_rc)." >&2
    echo "Resolve the repository issue shown above, then rerun:" >&2
    echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 4.1" >&2
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  load_model_config "$models_path" "$REPO_BR_SCAN_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$REPO_BR_SCAN_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_repo_br_scan_prompt "$runtime_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  return "$model_rc"
}

build_br_clarification_prompt() {
  local runtime_root="$1"
  local feature_br_file="$FEATURE_PATH/feature_br_summary.md"
  local missing_data_file="$FEATURE_PATH/missing_br_data.md"

  cat <<EOF
Load and follow the overmind-br-clarification skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Feature BR summary artifact: $feature_br_file
- Missing-data artifact: $missing_data_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-br-clarification skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context br-clarification $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate br-clarification $FEATURE_PATH
EOF
}

run_br_clarification_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_br_file="$runtime_root/$FEATURE_PATH/feature_br_summary.md"
  local missing_data_file="$runtime_root/$FEATURE_PATH/missing_br_data.md"
  local prompt_arg=""
  local model_rc=0

  [[ -f "$feature_br_file" ]] || die "Required file not found: $FEATURE_PATH/feature_br_summary.md"
  [[ -f "$missing_data_file" ]] || die "Required file not found: $FEATURE_PATH/missing_br_data.md"
  [[ -f "$runtime_root/$BR_CLARIFICATION_SKILL_FILE" ]] || die "Required skill not found: $BR_CLARIFICATION_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  load_model_config "$models_path" "$BR_CLARIFICATION_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$BR_CLARIFICATION_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_br_clarification_prompt "$runtime_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  return "$model_rc"
}

run_br_clarification_readiness() {
  local runtime_root="$1"
  local readiness_rc=0

  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"
  require_command node

  set +e
  (
    cd "$runtime_root"
    node "$OVERMIND_CLI_FILE" readiness br-clarification "$FEATURE_PATH"
  )
  readiness_rc=$?
  set -e

  return "$readiness_rc"
}

build_requirements_ears_prompt() {
  local runtime_root="$1"
  local feature_br_file="$FEATURE_PATH/feature_br_summary.md"
  local requirements_ears_file="$FEATURE_PATH/requirements_ears.md"

  cat <<EOF
Load and follow the overmind-requirements-ears skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Read-only BR summary artifact: $feature_br_file
- Target EARS artifact: $requirements_ears_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-requirements-ears skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context requirements-ears $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate requirements-ears $FEATURE_PATH
EOF
}

run_requirements_ears_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_br_file="$runtime_root/$FEATURE_PATH/feature_br_summary.md"
  local prompt_arg=""
  local model_rc=0
  local before_snapshot=""

  [[ -f "$feature_br_file" ]] || die "Required file not found: $FEATURE_PATH/feature_br_summary.md"
  [[ -f "$runtime_root/$REQUIREMENTS_EARS_SKILL_FILE" ]] || die "Required skill not found: $REQUIREMENTS_EARS_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  load_model_config "$models_path" "$REQUIREMENTS_EARS_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$REQUIREMENTS_EARS_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_requirements_ears_prompt "$runtime_root")"
  before_snapshot="$(mktemp)"
  cp "$feature_br_file" "$before_snapshot"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  if [[ "$model_rc" -ne 0 ]]; then
    rm -f "$before_snapshot"
    return "$model_rc"
  fi

  if ! cmp -s "$before_snapshot" "$feature_br_file"; then
    rm -f "$before_snapshot"
    die "Requirements-EARS skill must not modify $FEATURE_PATH/feature_br_summary.md; it is read-only input."
  fi
  rm -f "$before_snapshot"

  return 0
}

build_ears_review_prompt() {
  local runtime_root="$1"
  local feature_br_file="$FEATURE_PATH/feature_br_summary.md"
  local requirements_ears_file="$FEATURE_PATH/requirements_ears.md"
  local review_file="$FEATURE_PATH/requirements_ears_review.md"

  cat <<EOF
Load and follow the overmind-ears-review skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Read-only BR summary artifact: $feature_br_file
- Mutable EARS artifact: $requirements_ears_file
- Review ledger artifact: $review_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-ears-review skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context ears-review $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate ears-review $FEATURE_PATH
EOF
}

run_ears_review_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_br_file="$runtime_root/$FEATURE_PATH/feature_br_summary.md"
  local requirements_ears_file="$runtime_root/$FEATURE_PATH/requirements_ears.md"
  local review_file="$runtime_root/$FEATURE_PATH/requirements_ears_review.md"
  local prompt_arg=""
  local model_rc=0
  local before_snapshot=""

  [[ -f "$feature_br_file" ]] || die "Required file not found: $FEATURE_PATH/feature_br_summary.md"
  [[ -f "$requirements_ears_file" ]] || die "Required file not found: $FEATURE_PATH/requirements_ears.md"
  [[ -f "$runtime_root/$EARS_REVIEW_SKILL_FILE" ]] || die "Required skill not found: $EARS_REVIEW_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  load_model_config "$models_path" "$EARS_REVIEW_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$EARS_REVIEW_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_ears_review_prompt "$runtime_root")"
  before_snapshot="$(mktemp)"
  cp "$feature_br_file" "$before_snapshot"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  if ! cmp -s "$before_snapshot" "$feature_br_file"; then
    rm -f "$before_snapshot"
    die "EARS-review skill must not modify $FEATURE_PATH/feature_br_summary.md; it is read-only input."
  fi
  rm -f "$before_snapshot"

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi

  [[ -f "$review_file" ]] || die "EARS-review model run did not produce required file: $FEATURE_PATH/requirements_ears_review.md"

  echo "Updated $FEATURE_PATH/requirements_ears.md"
  echo "Updated $FEATURE_PATH/requirements_ears_review.md"
}

build_surface_map_enrich_prompt() {
  local runtime_root="$1"

  cat <<EOF
Load and follow the overmind-surface-map-enrich skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-surface-map-enrich skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context surface-map-enrich $FEATURE_PATH
- When the skill tells you to validate, use the per-class gate command:
  node $OVERMIND_CLI_FILE gate surface-map $FEATURE_PATH --class <backend|frontend|mobile>
- The model owns the gate loop; this orchestrator does not run the gate.
EOF
}

run_surface_map_enrich_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local sources_path="$runtime_root/.setup/external_sources.yaml"
  local definition_path="$runtime_root/$PROJECT_PATH/init_progress_definition.yaml"
  local prompt_arg=""
  local model_rc=0
  local before_sources=""
  local before_definition=""
  local sources_existed="no"
  local definition_existed="no"

  [[ -f "$runtime_root/$SURFACE_MAP_ENRICH_SKILL_FILE" ]] || die "Required skill not found: $SURFACE_MAP_ENRICH_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  load_model_config "$models_path" "$SURFACE_MAP_ENRICH_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$SURFACE_MAP_ENRICH_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_sources="$(mktemp)"
  if [[ -f "$sources_path" ]]; then
    cp "$sources_path" "$before_sources"
    sources_existed="yes"
  fi
  before_definition="$(mktemp)"
  if [[ -f "$definition_path" ]]; then
    cp "$definition_path" "$before_definition"
    definition_existed="yes"
  fi

  prompt_arg="$(build_surface_map_enrich_prompt "$runtime_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  if [[ "$sources_existed" == "yes" ]]; then
    if ! [[ -f "$sources_path" ]]; then
      rm -f "$before_sources" "$before_definition"
      die "Surface-map-enrich skill must not delete or replace .setup/external_sources.yaml; it is read-only input."
    elif ! cmp -s "$before_sources" "$sources_path"; then
      rm -f "$before_sources" "$before_definition"
      die "Surface-map-enrich skill must not modify .setup/external_sources.yaml; it is read-only input."
    fi
  elif [[ -e "$sources_path" ]]; then
    rm -f "$before_sources" "$before_definition"
    die "Surface-map-enrich skill must not create .setup/external_sources.yaml; it is read-only input."
  fi
  rm -f "$before_sources"

  if [[ "$definition_existed" == "yes" ]]; then
    if ! [[ -f "$definition_path" ]]; then
      rm -f "$before_definition"
      die "Surface-map-enrich skill must not delete or replace $PROJECT_PATH/init_progress_definition.yaml; it is read-only input."
    elif ! cmp -s "$before_definition" "$definition_path"; then
      rm -f "$before_definition"
      die "Surface-map-enrich skill must not modify $PROJECT_PATH/init_progress_definition.yaml; it is read-only input."
    fi
  elif [[ -e "$definition_path" ]]; then
    rm -f "$before_definition"
    die "Surface-map-enrich skill must not create $PROJECT_PATH/init_progress_definition.yaml; it is read-only input."
  fi
  rm -f "$before_definition"

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi
}

build_contract_delta_prompt() {
  local runtime_root="$1"
  local feature_contract_delta_file="$FEATURE_PATH/feature_contract_delta.md"

  cat <<EOF
Load and follow the overmind-contract-delta skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target contract delta artifact: $feature_contract_delta_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-contract-delta skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context contract-delta $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate contract-delta $FEATURE_PATH
EOF
}

run_contract_delta_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_abs="$runtime_root/$FEATURE_PATH"
  local output_file="$feature_abs/feature_contract_delta.md"
  local prompt_arg=""
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local sync_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local pending_file=""
  local snapshot=""
  local idx=0
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$CONTRACT_DELTA_SKILL_FILE" ]] || die "Required skill not found: $CONTRACT_DELTA_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  (cd "$runtime_root" && node "$OVERMIND_CLI_FILE" sync contract-delta "$FEATURE_PATH")
  sync_rc=$?
  set -e
  if [[ "$sync_rc" -ne 0 ]]; then
    echo "Execution stopped: phase 6 repo sync failed (exit $sync_rc)." >&2
    echo "Resolve the repository issue shown above, then rerun:" >&2
    echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 6" >&2
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context contract-delta "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    echo "Execution stopped: phase 6 contract-delta context failed (exit $context_rc)." >&2
    echo "Resolve the context issue shown above, then rerun:" >&2
    echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 6" >&2
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then
      resolved_read_only_path="$read_only_path"
    else
      resolved_read_only_path="$runtime_root/$read_only_path"
    fi
    [[ -f "$resolved_read_only_path" ]] || die "Contract-delta context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Contract-delta context emitted no read-only inputs."

  load_model_config "$models_path" "$CONTRACT_DELTA_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$CONTRACT_DELTA_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  for pending_file in "${read_only_files[@]}"; do
    snapshot="$(mktemp)"
    cp "$pending_file" "$snapshot"
    snapshots+=("$snapshot")
  done

  prompt_arg="$(build_contract_delta_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Contract-delta skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi
  [[ -f "$output_file" ]] || die "Contract-delta model run did not produce required file: $FEATURE_PATH/feature_contract_delta.md"
  echo "Updated $FEATURE_PATH/feature_contract_delta.md"
}

build_surface_map_prompt() {
  local runtime_root="$1"
  local target_class="$2"
  local surface_map_file="$FEATURE_PATH/project_surface_struct_resp_map_${target_class}.md"

  cat <<EOF
Load and follow the overmind-surface-map skill for this feature and class.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target class: $target_class
- Target surface map artifact: $surface_map_file
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-surface-map skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context surface-map $FEATURE_PATH --class $target_class
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate surface-map $FEATURE_PATH --class $target_class
EOF
}

run_surface_map_skill() {
  local runtime_root="$1"
  local target_class="$2"
  local models_path="$runtime_root/$MODELS_FILE"
  local feature_abs="$runtime_root/$FEATURE_PATH"
  local output_file="$feature_abs/project_surface_struct_resp_map_${target_class}.md"
  local prompt_arg=""
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local sync_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local pending_file=""
  local snapshot=""
  local idx=0
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$SURFACE_MAP_SKILL_FILE" ]] || die "Required skill not found: $SURFACE_MAP_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  (cd "$runtime_root" && node "$OVERMIND_CLI_FILE" sync surface-map "$FEATURE_PATH" --class "$target_class")
  sync_rc=$?
  set -e
  if [[ "$sync_rc" -ne 0 ]]; then
    echo "Execution stopped: phase 7 repo sync failed for class $target_class (exit $sync_rc)." >&2
    echo "Resolve the repository issue shown above, then rerun:" >&2
    echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 7" >&2
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context surface-map "$FEATURE_PATH" --class "$target_class")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    echo "Execution stopped: phase 7 surface-map context failed for class $target_class (exit $context_rc)." >&2
    echo "Resolve the context issue shown above, then rerun:" >&2
    echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 7" >&2
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then
      resolved_read_only_path="$read_only_path"
    else
      resolved_read_only_path="$runtime_root/$read_only_path"
    fi
    [[ -f "$resolved_read_only_path" ]] || die "Surface-map context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Surface-map context emitted no read-only inputs."

  load_model_config "$models_path" "$SURFACE_MAP_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$SURFACE_MAP_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  for pending_file in "${read_only_files[@]}"; do
    snapshot="$(mktemp)"
    cp "$pending_file" "$snapshot"
    snapshots+=("$snapshot")
  done

  prompt_arg="$(build_surface_map_prompt "$runtime_root" "$target_class")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Surface-map skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi
  [[ -f "$output_file" ]] || die "Surface-map model run did not produce required file: $FEATURE_PATH/project_surface_struct_resp_map_${target_class}.md"
  echo "Updated $FEATURE_PATH/project_surface_struct_resp_map_${target_class}.md"
}

build_technical_requirements_prompt() {
  local runtime_root="$1"

  cat <<EOF
Load and follow the overmind-technical-requirements skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target artifact: $FEATURE_PATH/technical_requirements.md
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-technical-requirements skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context technical-requirements $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate technical-requirements $FEATURE_PATH
- The model owns the gate loop; this orchestrator does not run the gate.
EOF
}

run_technical_requirements_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local output_file="$runtime_root/$FEATURE_PATH/technical_requirements.md"
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local file=""
  local snapshot=""
  local idx=0
  local prompt_arg=""
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$TECHNICAL_REQUIREMENTS_SKILL_FILE" ]] || die "Required skill not found: $TECHNICAL_REQUIREMENTS_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context technical-requirements "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    return "$context_rc"
  fi

  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then
      resolved_read_only_path="$read_only_path"
    else
      resolved_read_only_path="$runtime_root/$read_only_path"
    fi
    [[ -f "$resolved_read_only_path" ]] || die "Technical-requirements context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Technical-requirements context emitted no read-only inputs."

  load_model_config "$models_path" "$TECHNICAL_REQUIREMENTS_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$TECHNICAL_REQUIREMENTS_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  for file in "${read_only_files[@]}"; do
    snapshot="$(mktemp)"
    cp "$file" "$snapshot"
    snapshots+=("$snapshot")
  done

  prompt_arg="$(build_technical_requirements_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Technical-requirements skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi
  [[ -f "$output_file" ]] || die "Technical-requirements model run did not produce required file: $FEATURE_PATH/technical_requirements.md"
  echo "Updated $FEATURE_PATH/technical_requirements.md"
}

build_implementation_slices_prompt() {
  local runtime_root="$1"

  cat <<EOF
Load and follow the overmind-implementation-slices skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target artifact: $FEATURE_PATH/implementation_slices.md
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-implementation-slices skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context implementation-slices $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate implementation-slices $FEATURE_PATH
- The model owns the gate loop; this orchestrator does not run the gate.
EOF
}

run_implementation_slices_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local output_file="$runtime_root/$FEATURE_PATH/implementation_slices.md"
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local file=""
  local snapshot=""
  local idx=0
  local prompt_arg=""
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$IMPLEMENTATION_SLICES_SKILL_FILE" ]] || die "Required skill not found: $IMPLEMENTATION_SLICES_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context implementation-slices "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    return "$context_rc"
  fi

  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then
      resolved_read_only_path="$read_only_path"
    else
      resolved_read_only_path="$runtime_root/$read_only_path"
    fi
    [[ -f "$resolved_read_only_path" ]] || die "Implementation-slices context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Implementation-slices context emitted no read-only inputs."

  load_model_config "$models_path" "$IMPLEMENTATION_SLICES_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$IMPLEMENTATION_SLICES_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  for file in "${read_only_files[@]}"; do
    snapshot="$(mktemp)"
    cp "$file" "$snapshot"
    snapshots+=("$snapshot")
  done

  prompt_arg="$(build_implementation_slices_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  set +e
  (
    cd "$runtime_root"
    "${cmd[@]}"
  )
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Implementation-slices skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then
    return "$model_rc"
  fi
  [[ -f "$output_file" ]] || die "Implementation-slices model run did not produce required file: $FEATURE_PATH/implementation_slices.md"
  echo "Updated $FEATURE_PATH/implementation_slices.md"
}

build_prerequisite_gaps_prompt() {
  local runtime_root="$1"
  cat <<EOF
Load and follow the overmind-prerequisite-gaps skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target artifact: $FEATURE_PATH/prerequisite_gaps.md
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-prerequisite-gaps skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context prerequisite-gaps $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate prerequisite-gaps $FEATURE_PATH
- The model owns the gate loop; this orchestrator does not run the gate.
EOF
}

run_prerequisite_gaps_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local output_file="$runtime_root/$FEATURE_PATH/prerequisite_gaps.md"
  local guard_context=""
  local context_rc=0
  local sync_rc=0
  local model_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local file=""
  local snapshot=""
  local idx=0
  local prompt_arg=""
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$PREREQUISITE_GAPS_SKILL_FILE" ]] || die "Required skill not found: $PREREQUISITE_GAPS_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  (cd "$runtime_root" && node "$OVERMIND_CLI_FILE" sync prerequisite-gaps "$FEATURE_PATH")
  sync_rc=$?
  set -e
  if [[ "$sync_rc" -ne 0 ]]; then
    echo "Execution stopped: phase 8.2 repo sync failed (exit $sync_rc)." >&2
    return "$sync_rc"
  fi

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context prerequisite-gaps "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    return "$context_rc"
  fi

  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then resolved_read_only_path="$read_only_path"; else resolved_read_only_path="$runtime_root/$read_only_path"; fi
    [[ -f "$resolved_read_only_path" ]] || die "Prerequisite-gaps context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Prerequisite-gaps context emitted no read-only inputs."

  load_model_config "$models_path" "$PREREQUISITE_GAPS_MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$PREREQUISITE_GAPS_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  for file in "${read_only_files[@]}"; do snapshot="$(mktemp)"; cp "$file" "$snapshot"; snapshots+=("$snapshot"); done
  prompt_arg="$(build_prerequisite_gaps_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then cmd+=("${MODEL_ARGS[@]}"); fi
  cmd+=("$prompt_arg")

  set +e
  (cd "$runtime_root" && "${cmd[@]}")
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Prerequisite-gaps skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then return "$model_rc"; fi
  [[ -f "$output_file" ]] || die "Prerequisite-gaps model run did not produce required file: $FEATURE_PATH/prerequisite_gaps.md"
  echo "Updated $FEATURE_PATH/prerequisite_gaps.md"
}

build_implementation_plan_prompt() {
  local runtime_root="$1"
  cat <<EOF
Load and follow the overmind-implementation-plan skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Target artifact: $FEATURE_PATH/implementation_plan.md
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-implementation-plan skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context implementation-plan $FEATURE_PATH
- Use the exact gate command below when the skill tells you to validate:
  node $OVERMIND_CLI_FILE gate implementation-plan $FEATURE_PATH
- The model owns the gate loop; this orchestrator does not run the gate.
EOF
}

run_implementation_plan_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local output_file="$runtime_root/$FEATURE_PATH/implementation_plan.md"
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local file=""
  local snapshot=""
  local idx=0
  local prompt_arg=""
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$IMPLEMENTATION_PLAN_SKILL_FILE" ]] || die "Required skill not found: $IMPLEMENTATION_PLAN_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context implementation-plan "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    return "$context_rc"
  fi
  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then resolved_read_only_path="$read_only_path"; else resolved_read_only_path="$runtime_root/$read_only_path"; fi
    [[ -f "$resolved_read_only_path" ]] || die "Implementation-plan context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Implementation-plan context emitted no read-only inputs."

  load_model_config "$models_path" "$IMPLEMENTATION_PLAN_MODEL_PHASE"
  [[ "$MODEL_CMD" == "codex" ]] || die "Invalid '$IMPLEMENTATION_PLAN_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  require_command "$MODEL_CMD"
  for file in "${read_only_files[@]}"; do snapshot="$(mktemp)"; cp "$file" "$snapshot"; snapshots+=("$snapshot"); done
  prompt_arg="$(build_implementation_plan_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then cmd+=("${MODEL_ARGS[@]}"); fi
  cmd+=("$prompt_arg")
  set +e
  (cd "$runtime_root" && "${cmd[@]}")
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Implementation-plan skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
  if [[ "$model_rc" -ne 0 ]]; then return "$model_rc"; fi
  [[ -f "$output_file" ]] || die "Implementation-plan model run did not produce required file: $FEATURE_PATH/implementation_plan.md"
  echo "Updated $FEATURE_PATH/implementation_plan.md"
}

build_plan_semantic_review_prompt() {
  local runtime_root="$1"
  cat <<EOF
Load and follow the overmind-plan-semantic-review skill for this feature.

Runtime bindings:
- ASDLC workspace root: $runtime_root
- Current working directory for all commands: $runtime_root
- Feature path: $FEATURE_PATH
- Overmind CLI: $OVERMIND_CLI_FILE

Required flow:
- Load and follow the overmind-plan-semantic-review skill.
- Assemble deterministic context with:
  node $OVERMIND_CLI_FILE context plan-semantic-review $FEATURE_PATH
- Use the exact review-ledger gate command when the skill tells you to validate the review ledger:
  node $OVERMIND_CLI_FILE gate plan-semantic-review $FEATURE_PATH
- Use the exact implementation-plan gate command when the skill tells you to validate the plan:
  node $OVERMIND_CLI_FILE gate implementation-plan $FEATURE_PATH
- The model owns both gate loops; this orchestrator does not run either gate.
EOF
}

run_plan_semantic_review_skill() {
  local runtime_root="$1"
  local models_path="$runtime_root/$MODELS_FILE"
  local output_file="$runtime_root/$FEATURE_PATH/implementation_plan_semantic_review.md"
  local guard_context=""
  local context_rc=0
  local model_rc=0
  local read_only_path=""
  local resolved_read_only_path=""
  local file=""
  local snapshot=""
  local idx=0
  local prompt_arg=""
  local read_only_files=()
  local snapshots=()

  [[ -f "$runtime_root/$PLAN_SEMANTIC_REVIEW_SKILL_FILE" ]] || die "Required skill not found: $PLAN_SEMANTIC_REVIEW_SKILL_FILE"
  [[ -f "$runtime_root/$OVERMIND_CLI_FILE" ]] || die "Required Overmind CLI not found: $OVERMIND_CLI_FILE"

  set +e
  guard_context="$(cd "$runtime_root" && node "$OVERMIND_CLI_FILE" context plan-semantic-review "$FEATURE_PATH")"
  context_rc=$?
  set -e
  if [[ "$context_rc" -ne 0 ]]; then
    [[ -z "$guard_context" ]] || printf '%s\n' "$guard_context" >&2
    return "$context_rc"
  fi
  while IFS= read -r read_only_path; do
    [[ -n "$read_only_path" ]] || continue
    if [[ "$read_only_path" == /* ]]; then resolved_read_only_path="$read_only_path"; else resolved_read_only_path="$runtime_root/$read_only_path"; fi
    [[ -f "$resolved_read_only_path" ]] || die "Plan-semantic-review context read-only input not found: $read_only_path"
    read_only_files+=("$resolved_read_only_path")
  done < <(printf '%s\n' "$guard_context" | sed -n 's/^- read_only_input: //p')
  [[ ${#read_only_files[@]} -gt 0 ]] || die "Plan-semantic-review context emitted no read-only inputs."

  load_model_config "$models_path" "$PLAN_SEMANTIC_REVIEW_MODEL_PHASE"
  [[ "$MODEL_CMD" == "codex" ]] || die "Invalid '$PLAN_SEMANTIC_REVIEW_MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  require_command "$MODEL_CMD"
  for file in "${read_only_files[@]}"; do snapshot="$(mktemp)"; cp "$file" "$snapshot"; snapshots+=("$snapshot"); done
  prompt_arg="$(build_plan_semantic_review_prompt "$runtime_root")"
  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then cmd+=("${MODEL_ARGS[@]}"); fi
  cmd+=("$prompt_arg")

  set +e
  (cd "$runtime_root" && "${cmd[@]}")
  model_rc=$?
  set -e

  for idx in "${!read_only_files[@]}"; do
    if ! cmp -s "${snapshots[$idx]}" "${read_only_files[$idx]}"; then
      for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done
      die "Plan-semantic-review skill must not modify ${read_only_files[$idx]#"$runtime_root/"}; it is read-only input."
    fi
  done
  for snapshot in "${snapshots[@]}"; do rm -f "$snapshot"; done

  if [[ "$model_rc" -ne 0 ]]; then return "$model_rc"; fi
  [[ -f "$output_file" ]] || die "Plan-semantic-review model run did not produce required file: $FEATURE_PATH/implementation_plan_semantic_review.md"
  echo "Updated $FEATURE_PATH/implementation_plan_semantic_review.md"
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
      ;;

    4.2)
      ;;
    5)
      ;;
    5.1)
      ;;
    6)
      ;;
    7)
      ;;
    7.1)
      ;;
    8)
      ;;
    8.1)
      ;;
    8.2)
      ;;
    8.3)
      ;;
    8.4)
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

select_phase7_pending_class() {
  local count=${#PHASE7_PENDING_REPO_CLASSES[@]}
  local class_selection=""
  local normalized_selection=""
  local idx=0

  if [[ "$count" -eq 0 ]]; then
    echo "No pending classes to analyze." >&2
    return 1
  fi

  if [[ "$count" -eq 1 ]]; then
    printf '%s' "${PHASE7_PENDING_REPO_CLASSES[0]}"
    return 0
  fi

  echo "Pending classes available to analyze:" >&2
  for idx in "${!PHASE7_PENDING_REPO_CLASSES[@]}"; do
    echo "  $((idx + 1)). ${PHASE7_PENDING_REPO_CLASSES[$idx]}" >&2
  done
  printf 'Select a class to analyze now (number or class name): ' >&2

  if ! IFS= read -r class_selection; then
    echo "Execution stopped: user input stream closed during class selection." >&2
    return 1
  fi
  normalized_selection="$(to_lower "$(trim_value "$class_selection")")"

  if [[ "$normalized_selection" =~ ^[0-9]+$ ]]; then
    idx=$((normalized_selection - 1))
    if (( idx >= 0 && idx < count )); then
      printf '%s' "${PHASE7_PENDING_REPO_CLASSES[$idx]}"
      return 0
    fi
  fi
  for idx in "${!PHASE7_PENDING_REPO_CLASSES[@]}"; do
    if [[ "${PHASE7_PENDING_REPO_CLASSES[$idx]}" == "$normalized_selection" ]]; then
      printf '%s' "${PHASE7_PENDING_REPO_CLASSES[$idx]}"
      return 0
    fi
  done

  echo "Invalid class selection: $class_selection" >&2
  return 1
}

run_phase7_loop() {
  local runtime_root="$1"
  local selection=""
  local normalized=""
  local completed_list=""
  local pending_list=""
  local script_rc=0
  while true; do
    refresh_phase7_status "$runtime_root"
    completed_list="$(format_class_list "${PHASE7_COMPLETED_REPO_CLASSES[@]-}")"
    pending_list="$(format_class_list "${PHASE7_PENDING_REPO_CLASSES[@]-}")"

    echo "Phase 7 class loop status for feature: $FEATURE_PATH"
    echo "Already picked/completed classes: $completed_list"
    echo "Pending classes: $pending_list"
    local has_pending=0
    [[ ${#PHASE7_PENDING_REPO_CLASSES[@]} -gt 0 ]] && has_pending=1

    echo "Phase 7 options:"
    if [[ "$has_pending" -eq 1 ]]; then
      echo "  1) Analyze one class now"
    fi
    echo "  2) Refresh class status"
    echo "  3) contract delta finished lets move forward"
    if [[ "$has_pending" -eq 1 ]]; then
      printf 'Choose [1/2/3]: ' >&2
    else
      printf 'Choose [2/3]: ' >&2
    fi

    if ! IFS= read -r selection; then
      echo "Execution stopped: user input stream closed during phase 7 loop."
      return 20
    fi

    normalized="$(to_lower "$(trim_value "$selection")")"
    case "$normalized" in
      1)
        local selected_class=""
        if ! selected_class="$(select_phase7_pending_class)"; then
          continue
        fi
        echo "Starting surface-map Codex session for class $selected_class."
        set +e
        run_surface_map_skill "$runtime_root" "$selected_class"
        script_rc=$?
        set -e
        if [[ "$script_rc" -ne 0 ]]; then
          print_restart_guidance "7" "overmind-surface-map skill ($selected_class)" "$script_rc"
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
    echo "Proceeding with pending classes: $(format_class_list "${PHASE7_PENDING_REPO_CLASSES[@]-}")"
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

read_deferred_attach_candidate_classes() {
  local definition_path="$1"

  awk '
    BEGIN { in_block = 0; current_class = "" }
    /^  class_repo_paths:[[:space:]]*$/ {
      in_block = 1
      next
    }
    in_block && /^[^ ]/ {
      in_block = 0
      current_class = ""
      next
    }
    in_block && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ {
      line = $0
      sub(/^    /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      current_class = line
      next
    }
    in_block && current_class != "" && /^      state: / {
      line = $0
      sub(/^[[:space:]]*state:[[:space:]]*/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      if (line != "ready") {
        print current_class
      }
    }
  ' "$definition_path"
}

read_ready_reconciliation_candidate_classes() {
  local definition_path="$1"

  awk '
    BEGIN { in_block = 0; current_class = "" }
    /^  class_repo_paths:[[:space:]]*$/ {
      in_block = 1
      next
    }
    in_block && /^[^ ]/ {
      in_block = 0
      current_class = ""
      next
    }
    in_block && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ {
      line = $0
      sub(/^    /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      current_class = line
      next
    }
    in_block && current_class != "" && /^      state: / {
      line = $0
      sub(/^[[:space:]]*state:[[:space:]]*/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      if (line == "ready") {
        print current_class
      }
    }
  ' "$definition_path"
}

has_ready_class_repo_paths() {
  local definition_path="$1"
  local class_name=""

  [[ -f "$definition_path" ]] || return 1

  while IFS= read -r class_name; do
    [[ -n "$class_name" ]] && return 0
  done < <(read_ready_reconciliation_candidate_classes "$definition_path")

  return 1
}

run_contract_reconciliation_for_classes() {
  local runtime_root="$1"
  local input_fd="$2"
  shift 2
  local project_abs_path="$runtime_root/$PROJECT_PATH"
  local command_path="$runtime_root/.commands/project_contract_reconciliation.sh"
  local class_name=""
  local -a cmd_args=()

  [[ "$#" -gt 0 ]] || return 0
  [[ -x "$command_path" ]] || die "Required script not found or not executable: .commands/project_contract_reconciliation.sh"

  cmd_args=(--path "$project_abs_path")
  for class_name in "$@"; do
    cmd_args+=(--class "$class_name")
  done

  # One session reconciles every newly-attached (markerless) class at once.
  if [[ -n "$input_fd" ]]; then
    "$command_path" "${cmd_args[@]}" <&"$input_fd"
  else
    "$command_path" "${cmd_args[@]}"
  fi

  # Mark each covered class only after the single session succeeds; a failed run
  # leaves every marker unwritten so the next feature-start retries the full set.
  for class_name in "$@"; do
    : >"$project_abs_path/.contract_reconciled_$class_name"
  done
}

begin_reconciliation_transaction() {
  local runtime_root="$1"
  local project_abs_path="$runtime_root/$PROJECT_PATH"

  [[ "$RECONCILIATION_TRANSACTION_STARTED" == "false" ]] || return 0

  command -v git >/dev/null 2>&1 || {
    RECONCILIATION_TRANSACTION_STARTED="true"
    return 0
  }
  [[ -e "$project_abs_path/.git" ]] || {
    RECONCILIATION_TRANSACTION_STARTED="true"
    return 0
  }
  git -C "$project_abs_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    RECONCILIATION_TRANSACTION_STARTED="true"
    return 0
  }
  [[ -z "$(git -C "$project_abs_path" status --porcelain)" ]] || {
    die "Project worktree must be clean before repo attachment and contract reconciliation: $PROJECT_PATH"
  }

  RECONCILIATION_TRANSACTION_STARTED="true"
}

attempt_class_repo_attach() {
  local runtime_root="$1"
  local class_name="$2"
  local repo_path="$3"
  local helper_path="$runtime_root/common_libs/persist_class_repo_attach.sh"
  local helper_output=""
  local helper_rc=0

  [[ -x "$helper_path" ]] || die "Required command lib not found or not executable: common_libs/persist_class_repo_attach.sh"
  begin_reconciliation_transaction "$runtime_root"

  set +e
  helper_output="$("$helper_path" "$runtime_root/$PROJECT_PATH" "$class_name" "$repo_path" 2>&1)"
  helper_rc=$?
  set -e

  if [[ "$helper_rc" -ne 0 ]]; then
    printf '%s\n' "$helper_output" >&2
    return "$helper_rc"
  fi

  return 0
}

prompt_attach_deferred_class_repo() {
  local runtime_root="$1"
  local class_name="$2"
  local input_fd="$3"
  local answer=""
  local retry_answer=""

  printf "Class '%s' is blueprint-only. If its repo already exists, enter a valid path to attach it (policy C: repo becomes authoritative; blueprint is consulted only for subsystems absent from the repo); leave blank to keep it deferred.\n" "$class_name" >&2
  if ! IFS= read -r answer <&"$input_fd"; then
    return 0
  fi

  answer="$(trim_value "$answer")"
  [[ -n "$answer" ]] || return 0

  # Reconciliation is intentionally not run here. It runs once after the whole
  # attach loop (reconcile_ready_classes_missing_markers), so the operator can
  # attach every repo they intend to before any reconciliation starts (D10).
  if attempt_class_repo_attach "$runtime_root" "$class_name" "$answer"; then
    return 0
  fi

  printf "Class '%s' is blueprint-only. If its repo already exists, enter a valid path to attach it (policy C: repo becomes authoritative; blueprint is consulted only for subsystems absent from the repo); leave blank to keep it deferred.\n" "$class_name" >&2
  if ! IFS= read -r retry_answer <&"$input_fd"; then
    return 0
  fi

  retry_answer="$(trim_value "$retry_answer")"
  [[ -n "$retry_answer" ]] || return 0
  if attempt_class_repo_attach "$runtime_root" "$class_name" "$retry_answer"; then
    return 0
  fi
}

maybe_prompt_for_deferred_class_repo_attaches() {
  local runtime_root="$1"
  local project_abs_path="$runtime_root/$PROJECT_PATH"
  local definition_path="$project_abs_path/init_progress_definition.yaml"
  local class_name=""

  [[ -f "$definition_path" ]] || return 0

  exec 9<&0
  while IFS= read -r class_name; do
    [[ -n "$class_name" ]] || continue
    prompt_attach_deferred_class_repo "$runtime_root" "$class_name" 9
  done < <(read_deferred_attach_candidate_classes "$definition_path")
  exec 9<&-
}

reconcile_ready_classes_missing_markers() {
  local runtime_root="$1"
  local project_abs_path="$runtime_root/$PROJECT_PATH"
  local definition_path="$project_abs_path/init_progress_definition.yaml"
  local class_name=""
  local -a pending_classes=()

  [[ -f "$definition_path" ]] || return 0

  # Reconcile only ready classes that have not been reconciled yet; an existing
  # marker means a previous session already covered that class, so it stays out.
  while IFS= read -r class_name; do
    [[ -n "$class_name" ]] || continue
    [[ -f "$project_abs_path/.contract_reconciled_$class_name" ]] && continue
    pending_classes+=("$class_name")
  done < <(read_ready_reconciliation_candidate_classes "$definition_path")

  [[ "${#pending_classes[@]}" -gt 0 ]] || return 0
  begin_reconciliation_transaction "$runtime_root"

  # Reconciliation is an interactive model session, so it must read the operator's
  # stdin (fd 9 dup), not any process substitution redirected over fd 0.
  exec 9<&0
  run_contract_reconciliation_for_classes "$runtime_root" 9 "${pending_classes[@]}"
  exec 9<&-
  RECONCILIATION_RAN="true"
  RECONCILED_CLASSES_THIS_RUN=("${pending_classes[@]}")
}

commit_reconciliation_unit() {
  local runtime_root="$1"
  local project_abs_path="$runtime_root/$PROJECT_PATH"
  local answer=""
  local class_name=""
  local remaining_changes=""
  local unexpected_changes=""
  local -a commit_paths=(
    "init_progress_definition.yaml"
    "common_contract_definition.md"
  )
  local -a status_pathspecs=(".")

  [[ "$RECONCILIATION_RAN" == "true" ]] || return 0
  [[ "${#RECONCILED_CLASSES_THIS_RUN[@]}" -gt 0 ]] || return 0

  for class_name in "${RECONCILED_CLASSES_THIS_RUN[@]}"; do
    commit_paths+=(".contract_reconciled_$class_name")
  done
  for class_name in "${commit_paths[@]}"; do
    status_pathspecs+=(":(exclude)$class_name")
  done

  command -v git >/dev/null 2>&1 || return 0
  [[ -e "$project_abs_path/.git" ]] || return 0
  git -C "$project_abs_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  if ! unexpected_changes="$(git -C "$project_abs_path" status --porcelain -- "${status_pathspecs[@]}")"; then
    die "Failed to validate reconciliation-owned paths."
  fi
  if [[ -n "$unexpected_changes" ]]; then
    for class_name in "${RECONCILED_CLASSES_THIS_RUN[@]}"; do
      rm -f "$project_abs_path/.contract_reconciled_$class_name"
    done
    echo "ERROR: Reconciliation created unexpected changes; completion markers were removed:" >&2
    printf '%s\n' "$unexpected_changes" >&2
    exit 1
  fi
  [[ -n "$(git -C "$project_abs_path" status --porcelain -- "${commit_paths[@]}")" ]] || return 0

  printf "Commit reconciliation results? [y/N] " >&2
  IFS= read -r answer || answer=""
  case "$answer" in
  y | Y | yes | YES)
    git -C "$project_abs_path" add -- "${commit_paths[@]}" || die "Failed to stage reconciliation results."
    if git -C "$project_abs_path" diff --cached --quiet -- "${commit_paths[@]}"; then
      echo "No reconciliation results to commit."
      return 0
    fi
    git -C "$project_abs_path" commit -m "Reconcile contract and attach repos" -- "${commit_paths[@]}" >/dev/null \
      || die "Failed to commit reconciliation results."
    if ! remaining_changes="$(git -C "$project_abs_path" status --porcelain)"; then
      die "Failed to verify project worktree after committing reconciliation results."
    fi
    if [[ -n "$remaining_changes" ]]; then
      echo "ERROR: Reconciliation left unexpected uncommitted changes:" >&2
      printf '%s\n' "$remaining_changes" >&2
      exit 1
    fi
    echo "Committed reconciliation results for $PROJECT_PATH"
    ;;
  *)
    echo "Leaving reconciliation results uncommitted at operator request."
    return 20
    ;;
  esac
}

run_scanner_and_get_next_step() {
  local runtime_root="$1"
  local scanner_path="$runtime_root/.commands/init_progress_scanner.sh"
  local scanner_output=""
  local parsed_value=""

  [[ -x "$scanner_path" ]] || die "Required script not found or not executable: .commands/init_progress_scanner.sh"

  scanner_output="$("$scanner_path" --path "$FEATURE_PATH")"
  printf '%s\n' "$scanner_output"

  parsed_value="$(parse_scanner_next_step_line "$scanner_output")" || die "Unable to parse scanner output: missing canonical 'next step:' line."
  SCANNER_NEXT_STEP_INFO="$parsed_value"
}

map_scanner_step_to_phase() {
  local scanner_step_number="$1"
  local scanner_step_name="$2"
  local normalized_name
  normalized_name="$(to_lower "$scanner_step_name")"

  case "$scanner_step_number" in
    3) printf '%s' "3"; return 0 ;;
    4) printf '%s' "5"; return 0 ;;
    4.1) printf '%s' "4.1"; return 0 ;;
    4.2) printf '%s' "4.2"; return 0 ;;
    5) printf '%s' "5"; return 0 ;;
    5.1) printf '%s' "5.1"; return 0 ;;
    6) printf '%s' "6"; return 0 ;;
    7) printf '%s' "7"; return 0 ;;
    7.1) printf '%s' "7.1"; return 0 ;;
    8) printf '%s' "8"; return 0 ;;
    8.1) printf '%s' "8.1"; return 0 ;;
    8.2) printf '%s' "8.2"; return 0 ;;
    8.3) printf '%s' "8.3"; return 0 ;;
    8.4) printf '%s' "8.4"; return 0 ;;
  esac

  case "$normalized_name" in
    *"initialize and enrich business requirements structuring"*) printf '%s' "3"; return 0 ;;
    *"scan repo"* ) printf '%s' "4.1"; return 0 ;;
    *"task to br"* ) printf '%s' "4.1"; return 0 ;;
    *"business requirements clarification"* ) printf '%s' "4.2"; return 0 ;;
    *"readiness"* ) printf '%s' "4.2"; return 0 ;;
    *"convert business requirements structuring to ears"*) printf '%s' "5"; return 0 ;;
    *"convert br to ears"*) printf '%s' "5"; return 0 ;;
    *"requirement_ears extra review"*) printf '%s' "5.1"; return 0 ;;
    *"define feature contract delta"*) printf '%s' "6"; return 0 ;;
    *"analyze repos and prepare repo execution context"*) printf '%s' "7"; return 0 ;;
    *"create feature-scoped technical requirements"*) printf '%s' "8"; return 0 ;;
    *"mcp placeholder enrichment"*) printf '%s' "7.1"; return 0 ;;
    *"create implementation slice planning artifact"*) printf '%s' "8.1"; return 0 ;;
    *"run prerequisite gap trace"*) printf '%s' "8.2"; return 0 ;;
    *"create shared repository implementation plan"*) printf '%s' "8.3"; return 0 ;;
    *"implementation plan semantic review"*) printf '%s' "8.4"; return 0 ;;
  esac

  return 1
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
    7|6|repo-surface) printf '%s' "7" ;;
    7.1|mcp-placeholder-enrichment) printf '%s' "7.1" ;;
    8|technical-requirements) printf '%s' "8" ;;
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
  if [[ "$phase_id" == "4.1" ]]; then
    if has_ready_class_repo_paths "$RUNTIME_ROOT/$PROJECT_PATH/init_progress_definition.yaml"; then
      echo "Starting repo-br-scan Codex session for $FEATURE_PATH."
      set +e
      run_repo_br_scan_skill "$runtime_root"
      script_rc=$?
      set -e
      if [[ "$script_rc" -ne 0 ]]; then
        echo "Execution stopped: phase 4.1 failed while running overmind-repo-br-scan skill (exit $script_rc)." >&2
        echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
        echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 4.1" >&2
        return "$PHASE_EXECUTION_FAILED_RC"
      fi
    else
      echo "Skipping repo scan in phase 4.1: no class_repo_paths entries have state ready."
    fi
    echo "Starting task-to-BR Codex session for $FEATURE_PATH."
    set +e
    run_task_to_br_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 4.1 failed while running overmind-task-to-br skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 4.1" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "4.2" ]]; then
    command_text="overmind-br-clarification skill for $FEATURE_PATH; then node $OVERMIND_CLI_FILE readiness br-clarification $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting BR-clarification Codex session for $FEATURE_PATH."
    set +e
    run_br_clarification_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 4.2 failed while running overmind-br-clarification skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 4.2" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi

    set +e
    run_br_clarification_readiness "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 4.2 failed while running readiness br-clarification (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 4.2" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "5" ]]; then
    command_text="overmind-requirements-ears skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting requirements-EARS Codex session for $FEATURE_PATH."
    set +e
    run_requirements_ears_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 5 failed while running overmind-requirements-ears skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 5" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "5.1" ]]; then
    command_text="overmind-ears-review skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Optional phase declined at $phase_id; skipping."
      if has_later_required_phase "$phase_idx"; then
        return 10
      fi
      echo "Execution finished: no remaining required phases after declined optional phase $phase_id."
      return 30
    fi

    echo "Starting EARS-review Codex session for $FEATURE_PATH."
    set +e
    run_ears_review_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 5.1 failed while running overmind-ears-review skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 5.1" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "6" ]]; then
    command_text="overmind-contract-delta skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting contract-delta Codex session for $FEATURE_PATH."
    set +e
    run_contract_delta_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 6 failed while running overmind-contract-delta skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 6" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "7.1" ]]; then
    command_text="overmind-surface-map-enrich skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Optional phase declined at $phase_id; skipping."
      if has_later_required_phase "$phase_idx"; then
        return 10
      fi
      echo "Execution finished: no remaining required phases after declined optional phase $phase_id."
      return 30
    fi

    echo "Starting surface-map-enrich Codex session for $FEATURE_PATH."
    set +e
    run_surface_map_enrich_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 7.1 failed while running overmind-surface-map-enrich skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 7.1" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "8" ]]; then
    command_text="overmind-technical-requirements skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting technical-requirements Codex session for $FEATURE_PATH."
    set +e
    run_technical_requirements_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 8 failed while running overmind-technical-requirements skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 8" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "8.1" ]]; then
    command_text="overmind-implementation-slices skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting implementation-slices Codex session for $FEATURE_PATH."
    set +e
    run_implementation_slices_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 8.1 failed while running overmind-implementation-slices skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 8.1" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "8.2" ]]; then
    command_text="overmind-prerequisite-gaps skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    echo "Starting prerequisite-gaps Codex session for $FEATURE_PATH."
    set +e
    run_prerequisite_gaps_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 8.2 failed while running overmind-prerequisite-gaps skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 8.2" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "8.3" ]]; then
    command_text="overmind-implementation-plan skill for $FEATURE_PATH"
    if ! confirm_start "$phase_id" "1" "1" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi
    echo "Starting implementation-plan Codex session for $FEATURE_PATH."
    set +e
    run_implementation_plan_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 8.3 failed while running overmind-implementation-plan skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 8.3" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
  if [[ "$phase_id" == "8.4" ]]; then
    command_text="overmind-plan-semantic-review skill for $FEATURE_PATH"
    local decision_status=0
    set +e
    confirm_start "$phase_id" "1" "1" "$command_text"
    decision_status=$?
    set -e
    if [[ "$decision_status" -ne 0 ]]; then
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi
      echo "Optional phase declined at $phase_id; skipping."
      echo "Execution finished: no remaining required phases after declined optional phase $phase_id."
      return 30
    fi

    echo "Starting plan-semantic-review Codex session for $FEATURE_PATH."
    set +e
    run_plan_semantic_review_skill "$runtime_root"
    script_rc=$?
    set -e
    if [[ "$script_rc" -ne 0 ]]; then
      echo "Execution stopped: phase 8.4 failed while running overmind-plan-semantic-review skill (exit $script_rc)." >&2
      echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
      echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume 8.4" >&2
      return "$PHASE_EXECUTION_FAILED_RC"
    fi
    return 0
  fi
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
  if [[ -z "$TARGET_PATH_INPUT" ]]; then
    local project_selection_rc=0
    set +e
    auto_select_project_path "$RUNTIME_ROOT"
    project_selection_rc=$?
    set -e
    if [[ "$project_selection_rc" -eq 20 ]]; then
      exit 0
    fi
    if [[ "$project_selection_rc" -ne 0 ]]; then
      die "Unexpected project auto-selection status: $project_selection_rc"
    fi
  fi
  resolve_project_path "$RUNTIME_ROOT" "$TARGET_PATH_INPUT"
  PROJECT_TYPE_CODE="$(extract_project_type_code_from_definition "$RUNTIME_ROOT/$PROJECT_PATH/init_progress_definition.yaml")"
  maybe_prompt_for_deferred_class_repo_attaches "$RUNTIME_ROOT"
  reconcile_ready_classes_missing_markers "$RUNTIME_ROOT"
  local reconciliation_commit_rc=0
  set +e
  commit_reconciliation_unit "$RUNTIME_ROOT"
  reconciliation_commit_rc=$?
  set -e
  if [[ "$reconciliation_commit_rc" -eq 20 ]]; then
    echo "Execution stopped: reconciliation results were not committed."
    exit 0
  fi
  [[ "$reconciliation_commit_rc" -eq 0 ]] || die "Unexpected reconciliation commit status: $reconciliation_commit_rc"

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
    elif [[ "$requested_phase" == "8.4" && "$CACHED_FEATURE_PATH_STATE" == "valid" ]]; then
      FEATURE_PATH="$CACHED_FEATURE_PATH"
      echo "Resuming optional phase 8.4 for completed cached feature: $FEATURE_PATH"
    elif [[ -n "$requested_phase" && "$requested_phase" != "3" ]]; then
      die "No unfinished feature context for this project. Run without --resume or use --resume 3 first."
    else
      print_no_unfinished_features_message
    fi
  fi

  if [[ -z "$FEATURE_PATH" ]]; then
    local phase3_index=""
    phase3_index="$(phase_index "3")"

    local phase3_rc=0
    run_phase_by_index "$RUNTIME_ROOT" "$phase3_index" || phase3_rc=$?

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

  run_scanner_and_get_next_step "$RUNTIME_ROOT"
  scanner_step_info="$SCANNER_NEXT_STEP_INFO"
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
    case "${PHASE_IDS[$idx]}" in
      5.1)
        commit_feature_progress "before step 5.1 (EARS review)"
        ;;
      7.1)
        commit_feature_progress "before step 7.1 (MCP enrichment)"
        ;;
      8.4)
        commit_feature_progress "before step 8.4 (semantic review)"
        ;;
    esac

    local phase_rc=0
    run_phase_by_index "$RUNTIME_ROOT" "$idx" || phase_rc=$?

    if [[ "${PHASE_IDS[$idx]}" == "8.4" && ( "$phase_rc" -eq 0 || "$phase_rc" -eq 30 ) ]]; then
      commit_feature_progress "after step 8.4 (semantic review)"
    fi

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
