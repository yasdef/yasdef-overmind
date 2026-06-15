#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE=""
REQUIREMENTS_EARS_FILE=""
FEATURE_CONTRACT_DELTA_FILE=""
PROJECT_SURFACE_MAP_FILE=""

BACKEND_TEMPLATE_FILE=".templates/project_surface_struct_resp_map_be_TEMPLATE.md"
FRONTEND_MOBILE_TEMPLATE_FILE=".templates/project_surface_struct_resp_map_fe_TEMPLATE.md"
BACKEND_GOLDEN_EXAMPLE_FILE=".golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
FRONTEND_MOBILE_GOLDEN_EXAMPLE_FILE=".golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/feature_repo_surface_and_exec_context_rule.md"
BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
MODEL_PHASE="feature_repo_surface_and_exec_context"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
PROJECT_CLASSES=()
READY_REPO_CLASSES=()
READY_REPO_PATHS=()
READY_REPO_NOTES=()
TARGET_REPO_CLASS=""
TARGET_REPO_PATH=""
TARGET_TEMPLATE_FILE=""
TARGET_GOLDEN_EXAMPLE_FILE=""
TARGET_QUALITY_GATE_HELPER=""
TARGET_TRACK_LABEL=""
TARGET_PROJECT_CLASSES_VALUE=""
TARGET_BLUEPRINT_FILE=""
SYNC_REPO_TO_DEFAULT_BRANCH=""
LIST_COMMITTED_SIBLING_FEATURES=""
IN_FLIGHT_FEATURE_FOLDERS=()
OPTIONAL_READ_ONLY_PATHS=()
OPTIONAL_READ_ONLY_NAMES=()
OPTIONAL_READ_ONLY_SNAPSHOTS=()

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
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
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
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done

  [[ -n "$FEATURE_PATH_INPUT" ]] || die "Missing required argument: --feature_path <feature-folder-path>."
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
    "$runtime_root"/*) ;;
    *) die "Feature path must resolve inside ASDLC workspace: $resolved_path" ;;
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

set_common_artifact_paths() {
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  FEATURE_CONTRACT_DELTA_FILE="$FEATURE_PATH/feature_contract_delta.md"
}

ensure_common_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$PROJECT_DEFINITION_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$FEATURE_CONTRACT_DELTA_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

ensure_target_support_files() {
  local runtime_root="$1"
  local required_paths=(
    "$TARGET_TEMPLATE_FILE"
    "$TARGET_GOLDEN_EXAMPLE_FILE"
    "$TARGET_QUALITY_GATE_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
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
}

resolve_project_classes() {
  local definition_path="$1"
  local parsed_classes=""
  local class_name=""
  local normalized_class=""

  PROJECT_CLASSES=()

  if ! parsed_classes="$(extract_meta_project_classes "$definition_path" 2>/dev/null)"; then
    die "Failed to read meta_info.project_classes from $PROJECT_DEFINITION_FILE."
  fi

  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    normalized_class="$(printf '%s' "$class_name" | tr '[:upper:]' '[:lower:]')"

    case "$normalized_class" in
      backend|frontend|mobile|infrastructure)
        if ! array_contains "$normalized_class" "${PROJECT_CLASSES[@]-}"; then
          PROJECT_CLASSES+=("$normalized_class")
        fi
        ;;
      *) die "Unsupported project class in $PROJECT_DEFINITION_FILE: $class_name" ;;
    esac
  done <<<"$parsed_classes"

  if [[ ${#PROJECT_CLASSES[@]} -eq 0 ]]; then
    die "No supported project_classes found in $PROJECT_DEFINITION_FILE."
  fi
}

source_class_repo_paths_lib() {
  local runtime_root="$1"
  local lib_path="$runtime_root/common_libs/class_repo_paths.sh"
  [[ -f "$lib_path" ]] || die "Required command lib not found: common_libs/class_repo_paths.sh"
  # shellcheck source=/dev/null
  source "$lib_path"
}

resolve_sync_repo_helper() {
  local runtime_root="$1"
  SYNC_REPO_TO_DEFAULT_BRANCH="$runtime_root/common_libs/sync_repo_to_default_branch.sh"
  [[ -x "$SYNC_REPO_TO_DEFAULT_BRANCH" ]] || die "Required command lib not found or not executable: common_libs/sync_repo_to_default_branch.sh"
}

resolve_sibling_lister_helper() {
  local runtime_root="$1"
  LIST_COMMITTED_SIBLING_FEATURES="$runtime_root/common_libs/list_committed_sibling_features.sh"
  [[ -x "$LIST_COMMITTED_SIBLING_FEATURES" ]] || die "Required command lib not found or not executable: common_libs/list_committed_sibling_features.sh"
}

collect_in_flight_plan_sources() {
  local runtime_root="$1"
  local feature_abs_path="$runtime_root/$FEATURE_PATH"
  local sibling_features=""
  local sibling_folder=""

  IN_FLIGHT_FEATURE_FOLDERS=()

  if ! sibling_features="$("$LIST_COMMITTED_SIBLING_FEATURES" --feature_path "$feature_abs_path" 2>&1)"; then
    echo "$sibling_features" >&2
    exit 1
  fi

  while IFS= read -r sibling_folder; do
    sibling_folder="$(trim_value "$sibling_folder")"
    [[ -n "$sibling_folder" ]] || continue
    IN_FLIGHT_FEATURE_FOLDERS+=("$sibling_folder")
  done <<<"$sibling_features"
}

collect_surface_targets() {
  local definition_path="$1"
  local runtime_root="$2"
  local active_class=""
  local entry=""
  local state=""
  local normalized_state=""
  local ready_paths=""
  local resolved_path=""
  local blueprint_rel=""
  local synced_paths=()

  READY_REPO_CLASSES=()
  READY_REPO_PATHS=()
  READY_REPO_NOTES=()

  for active_class in "${PROJECT_CLASSES[@]}"; do
    case "$active_class" in
      backend|frontend|mobile) ;;
      *) continue ;;
    esac

    blueprint_rel="$PROJECT_ROOT/project_stack_blueprint_${active_class}.md"

    if ! entry="$(class_repo_paths_find_entry "$definition_path" "$active_class" 2>/dev/null)"; then
      READY_REPO_NOTES+=("$active_class: missing class_repo_paths entry")
      if [[ -f "$runtime_root/$blueprint_rel" ]]; then
        READY_REPO_CLASSES+=("$active_class")
        READY_REPO_PATHS+=("")
      fi
      continue
    fi

    IFS='|' read -r state _repo_path <<<"$entry"
    normalized_state="$(printf '%s' "$(trim_value "$state")" | tr '[:upper:]' '[:lower:]')"
    if [[ "$normalized_state" != "ready" ]]; then
      READY_REPO_NOTES+=("$active_class: state is '$normalized_state', not ready")
      if [[ -f "$runtime_root/$blueprint_rel" ]]; then
        READY_REPO_CLASSES+=("$active_class")
        READY_REPO_PATHS+=("")
      fi
      continue
    fi

    if ! ready_paths="$(class_repo_paths_collect_ready_paths "$definition_path" "$active_class" 2>&1)"; then
      READY_REPO_NOTES+=("$active_class: $ready_paths")
      if [[ -f "$runtime_root/$blueprint_rel" ]]; then
        READY_REPO_CLASSES+=("$active_class")
        READY_REPO_PATHS+=("")
      fi
      continue
    fi
    if [[ -z "$ready_paths" ]]; then
      READY_REPO_NOTES+=("$active_class: no ready repo path resolved")
      continue
    fi

    IFS='|' read -r _resolved_class resolved_path <<<"$ready_paths"
    if ! array_contains "$resolved_path" "${synced_paths[@]-}"; then
      "$SYNC_REPO_TO_DEFAULT_BRANCH" "$resolved_path"
      synced_paths+=("$resolved_path")
    fi
    READY_REPO_CLASSES+=("$active_class")
    READY_REPO_PATHS+=("$resolved_path")
  done

  if [[ ${#READY_REPO_CLASSES[@]} -eq 0 ]]; then
    local details=""
    local note=""
    for note in "${READY_REPO_NOTES[@]-}"; do
      details="$details
- $note"
    done
    die "No ready repository paths or stack blueprints found for active classes in $PROJECT_DEFINITION_FILE.${details}"
  fi
}

select_target_repo() {
  local selection=""
  local normalized_selection=""
  local idx=0
  local selected_index=-1

  if [[ ${#READY_REPO_CLASSES[@]} -eq 1 ]]; then
    TARGET_REPO_CLASS="${READY_REPO_CLASSES[0]}"
    TARGET_REPO_PATH="${READY_REPO_PATHS[0]}"
    if [[ -n "$TARGET_REPO_PATH" ]]; then
      echo "Only one analysis target available: $TARGET_REPO_CLASS -> $TARGET_REPO_PATH" >&2
    else
      echo "Only one analysis target available: $TARGET_REPO_CLASS" >&2
    fi
    return 0
  fi

  echo "Analysis targets available:" >&2
  for idx in "${!READY_REPO_CLASSES[@]}"; do
    if [[ -n "${READY_REPO_PATHS[$idx]}" ]]; then
      echo "  $((idx + 1)). ${READY_REPO_CLASSES[$idx]} -> ${READY_REPO_PATHS[$idx]}" >&2
    else
      echo "  $((idx + 1)). ${READY_REPO_CLASSES[$idx]}" >&2
    fi
  done

  while true; do
    echo "Select target to analyze now (number or class name):" >&2
    if ! read -r selection; then
      die "Failed to read analysis target selection."
    fi
    selection="$(trim_value "$selection")"
    [[ -n "$selection" ]] || continue

    if [[ "$selection" =~ ^[0-9]+$ ]]; then
      selected_index=$((selection - 1))
      if (( selected_index >= 0 && selected_index < ${#READY_REPO_CLASSES[@]} )); then
        TARGET_REPO_CLASS="${READY_REPO_CLASSES[$selected_index]}"
        TARGET_REPO_PATH="${READY_REPO_PATHS[$selected_index]}"
        return 0
      fi
    fi

    normalized_selection="$(printf '%s' "$selection" | tr '[:upper:]' '[:lower:]')"
    for idx in "${!READY_REPO_CLASSES[@]}"; do
      if [[ "${READY_REPO_CLASSES[$idx]}" == "$normalized_selection" ]]; then
        TARGET_REPO_CLASS="${READY_REPO_CLASSES[$idx]}"
        TARGET_REPO_PATH="${READY_REPO_PATHS[$idx]}"
        return 0
      fi
    done

    echo "Invalid selection: $selection" >&2
  done
}

configure_target_bindings() {
  case "$TARGET_REPO_CLASS" in
    backend)
      TARGET_TRACK_LABEL="backend"
      TARGET_PROJECT_CLASSES_VALUE="backend"
      TARGET_TEMPLATE_FILE="$BACKEND_TEMPLATE_FILE"
      TARGET_GOLDEN_EXAMPLE_FILE="$BACKEND_GOLDEN_EXAMPLE_FILE"
      TARGET_QUALITY_GATE_HELPER="$BACKEND_QUALITY_GATE_HELPER"
      PROJECT_SURFACE_MAP_FILE="$FEATURE_PATH/project_surface_struct_resp_map_backend.md"
      ;;
    frontend)
      TARGET_TRACK_LABEL="frontend"
      TARGET_PROJECT_CLASSES_VALUE="frontend"
      TARGET_TEMPLATE_FILE="$FRONTEND_MOBILE_TEMPLATE_FILE"
      TARGET_GOLDEN_EXAMPLE_FILE="$FRONTEND_MOBILE_GOLDEN_EXAMPLE_FILE"
      TARGET_QUALITY_GATE_HELPER="$FRONTEND_MOBILE_QUALITY_GATE_HELPER"
      PROJECT_SURFACE_MAP_FILE="$FEATURE_PATH/project_surface_struct_resp_map_frontend.md"
      ;;
    mobile)
      TARGET_TRACK_LABEL="mobile"
      TARGET_PROJECT_CLASSES_VALUE="mobile"
      TARGET_TEMPLATE_FILE="$FRONTEND_MOBILE_TEMPLATE_FILE"
      TARGET_GOLDEN_EXAMPLE_FILE="$FRONTEND_MOBILE_GOLDEN_EXAMPLE_FILE"
      TARGET_QUALITY_GATE_HELPER="$FRONTEND_MOBILE_QUALITY_GATE_HELPER"
      PROJECT_SURFACE_MAP_FILE="$FEATURE_PATH/project_surface_struct_resp_map_mobile.md"
      ;;
    *)
      die "Unsupported target repository class: $TARGET_REPO_CLASS"
      ;;
  esac
}

render_selected_repo_context_line() {
  if [[ -n "$TARGET_REPO_PATH" ]]; then
    printf '%s\n' "- $TARGET_REPO_CLASS: $TARGET_REPO_PATH"
  else
    printf '%s\n' "- $TARGET_REPO_CLASS: (no ready repository; blueprint evidence is primary planned structural evidence)"
  fi
}

render_in_flight_read_only_inputs() {
  local sibling_folder=""

  if [[ ${#IN_FLIGHT_FEATURE_FOLDERS[@]} -eq 0 ]]; then
    return 0
  fi

  for sibling_folder in "${IN_FLIGHT_FEATURE_FOLDERS[@]}"; do
    printf '\n  - %s/%s/implementation_plan.md' "$PROJECT_ROOT" "$sibling_folder"
  done
}

render_in_flight_context_lines() {
  local sibling_folder=""

  if [[ ${#IN_FLIGHT_FEATURE_FOLDERS[@]} -eq 0 ]]; then
    return 0
  fi

  printf '\n%s\n' "- In-flight promise evidence:"
  for sibling_folder in "${IN_FLIGHT_FEATURE_FOLDERS[@]}"; do
    printf '%s\n' "- In-flight plan source: $sibling_folder/implementation_plan.md"
  done
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

failure_line_for_target() {
  printf '%s' "repo surface and execution context ${TARGET_TRACK_LABEL} gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase"
}

success_line_for_target() {
  printf '%s' "Repo surface and execution context ${TARGET_TRACK_LABEL} phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"
}

build_prompt() {
  local runtime_root="$1"
  local quality_command="$TARGET_QUALITY_GATE_HELPER $PROJECT_SURFACE_MAP_FILE"
  local repo_context_line=""
  local failure_line=""
  local success_line=""
  local blueprint_read_only_input=""
  local blueprint_context=""
  local in_flight_read_only_inputs=""
  local in_flight_context_lines=""

  repo_context_line="$(render_selected_repo_context_line)"
  failure_line="$(failure_line_for_target)"
  success_line="$(success_line_for_target)"
  in_flight_read_only_inputs="$(render_in_flight_read_only_inputs)"
  in_flight_context_lines="$(render_in_flight_context_lines)"

  if [[ -n "$TARGET_BLUEPRINT_FILE" ]]; then
    local rel_blueprint="${TARGET_BLUEPRINT_FILE#"$runtime_root/"}"
    blueprint_read_only_input="
  - $rel_blueprint (stack blueprint fallback; planned structural evidence; per-field resolution chain in $RULE_FILE)"
    blueprint_context="
- Stack blueprint source: $rel_blueprint"
  fi

  cat <<EOF
Create repo execution-context artifact for the selected repository class for this feature.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this phase.
- Use $TARGET_TEMPLATE_FILE as structure contract for $PROJECT_SURFACE_MAP_FILE.
- Use $TARGET_GOLDEN_EXAMPLE_FILE as style contract for $PROJECT_SURFACE_MAP_FILE.
- Read these as input only and do not modify them:
  - $PROJECT_DEFINITION_FILE
  - $REQUIREMENTS_EARS_FILE
  - $FEATURE_CONTRACT_DELTA_FILE${blueprint_read_only_input}${in_flight_read_only_inputs}
- Update only: $PROJECT_SURFACE_MAP_FILE
- Use only the selected repository path listed below as scan scope.
- Before finishing, ensure output can pass this quality gate command: $quality_command
- Evaluate whether gate compliance is feasible with current inputs and constraints.
- If gate compliance is not feasible, stop and end with this exact line:
  "$failure_line"
- If quality gate is feasible with current inputs and passed, end your final response with this exact last line:
  "$success_line"

Track-specific bindings for shared rule:
- Target track: $TARGET_TRACK_LABEL
- Target repository class: $TARGET_REPO_CLASS
- Applicable project classes for this run: $TARGET_REPO_CLASS
- Artifact meta project_classes value: $TARGET_PROJECT_CLASSES_VALUE
- Structure contract file: $TARGET_TEMPLATE_FILE
- Style contract file: $TARGET_GOLDEN_EXAMPLE_FILE
- Quality gate command: $quality_command

Context:
- ASDLC workspace root: $runtime_root
- Project root: $PROJECT_ROOT
- Feature root: $FEATURE_PATH
- Project definition source: $PROJECT_DEFINITION_FILE
- Requirements source: $REQUIREMENTS_EARS_FILE
- Feature contract delta source: $FEATURE_CONTRACT_DELTA_FILE
- Selected repository to scan:
$repo_context_line${blueprint_context}${in_flight_context_lines}
- Target repo surface map artifact: $PROJECT_SURFACE_MAP_FILE
- Rule file: $RULE_FILE
- Template file: $TARGET_TEMPLATE_FILE
- Golden example file: $TARGET_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $TARGET_QUALITY_GATE_HELPER
- Quality gate command: $quality_command
EOF
}

ensure_file_unchanged() {
  local before_snapshot="$1"
  local target_path="$2"
  local relative_name="$3"

  if ! cmp -s "$before_snapshot" "$target_path"; then
    die "This phase must not modify $relative_name; it is read-only input."
  fi
}

collect_optional_read_only_inputs() {
  local runtime_root="$1"
  local sibling_folder=""
  local relative_path=""
  local full_path=""

  OPTIONAL_READ_ONLY_PATHS=()
  OPTIONAL_READ_ONLY_NAMES=()

  if [[ -n "$TARGET_BLUEPRINT_FILE" ]]; then
    relative_path="${TARGET_BLUEPRINT_FILE#"$runtime_root/"}"
    OPTIONAL_READ_ONLY_PATHS+=("$TARGET_BLUEPRINT_FILE")
    OPTIONAL_READ_ONLY_NAMES+=("$relative_path")
  fi

  if [[ ${#IN_FLIGHT_FEATURE_FOLDERS[@]} -gt 0 ]]; then
    for sibling_folder in "${IN_FLIGHT_FEATURE_FOLDERS[@]}"; do
      relative_path="$PROJECT_ROOT/$sibling_folder/implementation_plan.md"
      full_path="$runtime_root/$relative_path"
      [[ -f "$full_path" ]] || die "Required in-flight plan source not found: $relative_path"
      OPTIONAL_READ_ONLY_PATHS+=("$full_path")
      OPTIONAL_READ_ONLY_NAMES+=("$relative_path")
    done
  fi
}

snapshot_optional_read_only_inputs() {
  local snapshot_dir="$1"
  local idx=0
  local snapshot_path=""

  OPTIONAL_READ_ONLY_SNAPSHOTS=()

  if [[ ${#OPTIONAL_READ_ONLY_PATHS[@]} -eq 0 ]]; then
    return 0
  fi

  for idx in "${!OPTIONAL_READ_ONLY_PATHS[@]}"; do
    snapshot_path="$snapshot_dir/optional-read-only-$idx"
    cp "${OPTIONAL_READ_ONLY_PATHS[$idx]}" "$snapshot_path"
    OPTIONAL_READ_ONLY_SNAPSHOTS+=("$snapshot_path")
  done
}

ensure_optional_read_only_inputs_unchanged() {
  local idx=0

  if [[ ${#OPTIONAL_READ_ONLY_PATHS[@]} -eq 0 ]]; then
    return 0
  fi

  for idx in "${!OPTIONAL_READ_ONLY_PATHS[@]}"; do
    ensure_file_unchanged "${OPTIONAL_READ_ONLY_SNAPSHOTS[$idx]}" "${OPTIONAL_READ_ONLY_PATHS[$idx]}" "${OPTIONAL_READ_ONLY_NAMES[$idx]}"
  done
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  parse_args "$@"

  local runtime_root=""
  local definition_path=""
  local requirements_path=""
  local contract_delta_path=""
  local surface_map_path=""
  local models_path=""
  local prompt_arg=""
  local before_definition=""
  local before_requirements=""
  local before_contract_delta=""
  local optional_snapshot_dir=""

  runtime_root="$(ensure_staged_command_runtime)"
  source_class_repo_paths_lib "$runtime_root"
  resolve_sync_repo_helper "$runtime_root"
  resolve_sibling_lister_helper "$runtime_root"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root
  set_common_artifact_paths
  ensure_common_required_files "$runtime_root"
  collect_in_flight_plan_sources "$runtime_root"

  definition_path="$runtime_root/$PROJECT_DEFINITION_FILE"
  requirements_path="$runtime_root/$REQUIREMENTS_EARS_FILE"
  contract_delta_path="$runtime_root/$FEATURE_CONTRACT_DELTA_FILE"
  models_path="$runtime_root/$MODELS_FILE"

  resolve_project_classes "$definition_path"
  collect_surface_targets "$definition_path" "$runtime_root"
  select_target_repo
  TARGET_BLUEPRINT_FILE=""
  if [[ -f "$runtime_root/$PROJECT_ROOT/project_stack_blueprint_${TARGET_REPO_CLASS}.md" ]]; then
    TARGET_BLUEPRINT_FILE="$runtime_root/$PROJECT_ROOT/project_stack_blueprint_${TARGET_REPO_CLASS}.md"
  fi
  collect_optional_read_only_inputs "$runtime_root"
  configure_target_bindings
  ensure_target_support_files "$runtime_root"

  surface_map_path="$runtime_root/$PROJECT_SURFACE_MAP_FILE"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_definition="$(mktemp)"
  before_requirements="$(mktemp)"
  before_contract_delta="$(mktemp)"
  optional_snapshot_dir="$(mktemp -d)"
  cp "$definition_path" "$before_definition"
  cp "$requirements_path" "$before_requirements"
  cp "$contract_delta_path" "$before_contract_delta"
  snapshot_optional_read_only_inputs "$optional_snapshot_dir"
  trap '[[ -n "${before_definition:-}" ]] && rm -f "$before_definition"; [[ -n "${before_requirements:-}" ]] && rm -f "$before_requirements"; [[ -n "${before_contract_delta:-}" ]] && rm -f "$before_contract_delta"; [[ -n "${optional_snapshot_dir:-}" ]] && rm -rf "$optional_snapshot_dir"' EXIT

  prompt_arg="$(build_prompt "$runtime_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$runtime_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$surface_map_path" ]]; then
    die "Model run did not produce required file: $PROJECT_SURFACE_MAP_FILE"
  fi

  ensure_file_unchanged "$before_definition" "$definition_path" "$PROJECT_DEFINITION_FILE"
  ensure_file_unchanged "$before_requirements" "$requirements_path" "$REQUIREMENTS_EARS_FILE"
  ensure_file_unchanged "$before_contract_delta" "$contract_delta_path" "$FEATURE_CONTRACT_DELTA_FILE"
  ensure_optional_read_only_inputs_unchanged
  echo "Updated $PROJECT_SURFACE_MAP_FILE"
}

main "$@"
