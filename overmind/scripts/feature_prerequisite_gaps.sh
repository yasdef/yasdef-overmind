#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE=""
REQUIREMENTS_EARS_FILE=""
TECHNICAL_REQUIREMENTS_FILE=""
IMPLEMENTATION_SLICES_FILE=""
PREREQUISITE_GAPS_FILE=""

PREREQUISITE_GAPS_TEMPLATE_FILE=".templates/prerequisite_gaps_TEMPLATE.md"
PREREQUISITE_GAPS_GOLDEN_EXAMPLE_FILE=".golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/prerequisite_gaps_rule.md"
QUALITY_GATE_HELPER=".helper/check_prerequisite_gaps_quality.sh"
MODEL_PHASE="prerequisite_gap_trace"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
PROJECT_CLASSES=()
APPLICABLE_REPO_CLASSES=()
READONLY_INPUT_FILES=()
READONLY_SNAPSHOTS=()
SYNC_REPO_TO_DEFAULT_BRANCH=""
LIST_COMMITTED_SIBLING_FEATURES=""
IN_FLIGHT_FEATURE_FOLDERS=()

die() {
  echo "ERROR: $*" >&2
  exit 1
}

fail_project_type_undefined() {
  echo "unable to define project type" >&2
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

set_artifact_paths() {
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  TECHNICAL_REQUIREMENTS_FILE="$FEATURE_PATH/technical_requirements.md"
  IMPLEMENTATION_SLICES_FILE="$FEATURE_PATH/implementation_slices.md"
  PREREQUISITE_GAPS_FILE="$FEATURE_PATH/prerequisite_gaps.md"
}

extract_meta_scalar() {
  local definition_path="$1"
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
  in_meta = 0
  found = 0
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

  if ($0 ~ /^[[:space:]]+[a-z_]+:[[:space:]]*/) {
    key = $0
    sub(/^[[:space:]]+/, "", key)
    sub(/:.*$/, "", key)
    value = $0
    sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", value)
    value = strip_quotes(trim(value))
    if (key == target_key) {
      print value
      found = 1
      exit 0
    }
  }
}
END {
  if (!found) {
    exit 1
  }
}
' "$definition_path"
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

project_type_label_for_code() {
  case "$1" in
    A) printf '%s' "New project" ;;
    B) printf '%s' "Existing project with partial context" ;;
    C) printf '%s' "Existing project with code-first context" ;;
    *) return 1 ;;
  esac
}

resolve_project_type_code() {
  local definition_path="$1"
  local project_type_code=""
  local project_type_label=""
  local expected_label=""

  if ! project_type_code="$(extract_meta_scalar "$definition_path" "project_type_code" 2>/dev/null)"; then
    fail_project_type_undefined
  fi
  if ! project_type_label="$(extract_meta_scalar "$definition_path" "project_type_label" 2>/dev/null)"; then
    fail_project_type_undefined
  fi
  if ! expected_label="$(project_type_label_for_code "$project_type_code" 2>/dev/null)"; then
    fail_project_type_undefined
  fi
  if [[ "$project_type_label" != "$expected_label" ]]; then
    fail_project_type_undefined
  fi

  printf '%s' "$project_type_code"
}

resolve_project_classes() {
  local definition_path="$1"
  local parsed_classes=""
  local class_name=""
  local normalized_class=""

  PROJECT_CLASSES=()

  if ! parsed_classes="$(extract_meta_project_classes "$definition_path" 2>/dev/null)"; then
    fail_project_type_undefined
  fi

  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    normalized_class="$(printf '%s' "$class_name" | tr '[:upper:]' '[:lower:]')"

    case "$normalized_class" in
      backend | frontend | mobile | infrastructure)
        if ! array_contains "$normalized_class" "${PROJECT_CLASSES[@]-}"; then
          PROJECT_CLASSES+=("$normalized_class")
        fi
        ;;
      *)
        fail_project_type_undefined
        ;;
    esac
  done <<<"$parsed_classes"

  if [[ ${#PROJECT_CLASSES[@]} -eq 0 ]]; then
    fail_project_type_undefined
  fi
}

collect_supported_repo_classes() {
  local class_name=""

  APPLICABLE_REPO_CLASSES=()

  for class_name in "${PROJECT_CLASSES[@]}"; do
    case "$class_name" in
      backend | frontend | mobile)
        if ! array_contains "$class_name" "${APPLICABLE_REPO_CLASSES[@]-}"; then
          APPLICABLE_REPO_CLASSES+=("$class_name")
        fi
        ;;
      *)
        continue
        ;;
    esac
  done

  if [[ ${#APPLICABLE_REPO_CLASSES[@]} -eq 0 ]]; then
    die "No supported repo classes found for prerequisite gap trace in $PROJECT_DEFINITION_FILE."
  fi
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$PROJECT_DEFINITION_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$TECHNICAL_REQUIREMENTS_FILE"
    "$IMPLEMENTATION_SLICES_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$PREREQUISITE_GAPS_TEMPLATE_FILE"
    "$PREREQUISITE_GAPS_GOLDEN_EXAMPLE_FILE"
    "$QUALITY_GATE_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
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

sync_ready_supported_repo_paths() {
  local definition_path="$1"
  local entry=""
  local resolved_path=""
  local ready_paths=""

  if ! ready_paths="$(class_repo_paths_collect_ready_paths "$definition_path" "backend,frontend,mobile" 2>&1)"; then
    die "$ready_paths"
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r _class_name resolved_path <<<"$entry"
    "$SYNC_REPO_TO_DEFAULT_BRANCH" "$resolved_path"
  done <<<"$ready_paths"
}

prepare_readonly_inputs() {
  local runtime_root="$1"
  local sibling_folder=""
  local relative_path=""

  READONLY_INPUT_FILES=(
    "$PROJECT_DEFINITION_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$TECHNICAL_REQUIREMENTS_FILE"
    "$IMPLEMENTATION_SLICES_FILE"
  )

  if [[ ${#IN_FLIGHT_FEATURE_FOLDERS[@]} -gt 0 ]]; then
    for sibling_folder in "${IN_FLIGHT_FEATURE_FOLDERS[@]}"; do
      relative_path="$PROJECT_ROOT/$sibling_folder/implementation_plan.md"
      [[ -f "$runtime_root/$relative_path" ]] || die "Required in-flight plan source not found: $relative_path"
      READONLY_INPUT_FILES+=("$relative_path")
    done
  fi
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

failure_line() {
  printf '%s' "prerequisite gap trace gate cannot pass with current requirements/technical-requirements/slices inputs. Please provide instructions what to do, or adjust inputs and rerun this phase"
}

success_line() {
  printf '%s' "Prerequisite gap trace phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"
}

render_readonly_input_lines() {
  local path=""
  for path in "${READONLY_INPUT_FILES[@]}"; do
    printf '  - %s\n' "$path"
  done
}

render_repo_class_list() {
  local class_name=""
  local first="yes"
  for class_name in "${APPLICABLE_REPO_CLASSES[@]}"; do
    if [[ "$first" == "yes" ]]; then
      printf '%s' "$class_name"
      first="no"
    else
      printf ', %s' "$class_name"
    fi
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

build_prompt() {
  local runtime_root="$1"
  local project_type_code="$2"
  local quality_command="$QUALITY_GATE_HELPER $PREREQUISITE_GAPS_FILE $REQUIREMENTS_EARS_FILE $TECHNICAL_REQUIREMENTS_FILE"
  local failure_msg=""
  local success_msg=""
  local repo_class_list=""
  local readonly_lines=""
  local in_flight_context_lines=""

  failure_msg="$(failure_line)"
  success_msg="$(success_line)"
  repo_class_list="$(render_repo_class_list)"
  readonly_lines="$(render_readonly_input_lines)"
  in_flight_context_lines="$(render_in_flight_context_lines)"

  cat <<EOF
Run Step 8.2 prerequisite gap trace for this feature.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this phase.
- Keep this prompt concise: detailed derivation and formatting rules are owned by $RULE_FILE.
- Use $PREREQUISITE_GAPS_TEMPLATE_FILE as the structure contract for $PREREQUISITE_GAPS_FILE.
- Use $PREREQUISITE_GAPS_GOLDEN_EXAMPLE_FILE as the style contract for $PREREQUISITE_GAPS_FILE.
- Read these as input only and do not modify them:
$readonly_lines
- Update only: $PREREQUISITE_GAPS_FILE
- Derive externally-invocable prerequisites per EARS requirement using the class taxonomy in $RULE_FILE.
- Use $TECHNICAL_REQUIREMENTS_FILE user_reachable_surface subfields as the ground truth for present_in_repo status.
- Use $IMPLEMENTATION_SLICES_FILE as the ground truth for scheduled_in_slices status.
- Use prompt-bound sibling implementation_plan.md sources as the ground truth for scheduled_in_feature <feature-folder>/<step-id> status.
- If a missing prerequisite is covered by a sibling plan step, set status to scheduled_in_feature <feature-folder>/<step-id>, cite the sibling plan step in evidence, and keep slice_ref as none.
- Any unmet prerequisite must be resolved before this phase can pass the quality gate.
- Draft $PREREQUISITE_GAPS_FILE before running any quality gate command.
- Use this quality gate command before finalizing: $quality_command
- If you need to understand the gate, read $QUALITY_GATE_HELPER as a file; only execute $quality_command against a concrete draft artifact.
- Evaluate whether gate compliance is feasible with current inputs and constraints.
- If gate compliance is not feasible, stop and end with this exact line:
  "$failure_msg"
- If quality gate is feasible with current inputs and passed, end your final response with this exact last line:
  "$success_msg"

Context:
- ASDLC workspace root: $runtime_root
- Project root: $PROJECT_ROOT
- Feature root: $FEATURE_PATH
- Project type code: $project_type_code
- Active repo classes for this run: $repo_class_list
- Project definition source: $PROJECT_DEFINITION_FILE
- Requirements source: $REQUIREMENTS_EARS_FILE
- Technical requirements source: $TECHNICAL_REQUIREMENTS_FILE
- Implementation slices source: $IMPLEMENTATION_SLICES_FILE
- Sibling plan sources:${in_flight_context_lines:- none}
- Target artifact: $PREREQUISITE_GAPS_FILE
- Rule file: $RULE_FILE
- Template file: $PREREQUISITE_GAPS_TEMPLATE_FILE
- Golden example file: $PREREQUISITE_GAPS_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
EOF
}

snapshot_readonly_inputs() {
  local runtime_root="$1"
  local relative_path=""
  local snapshot_path=""

  READONLY_SNAPSHOTS=()
  for relative_path in "${READONLY_INPUT_FILES[@]}"; do
    snapshot_path="$(mktemp)"
    cp "$runtime_root/$relative_path" "$snapshot_path"
    READONLY_SNAPSHOTS+=("$snapshot_path")
  done
}

cleanup_snapshots() {
  local snapshot_path=""
  for snapshot_path in "${READONLY_SNAPSHOTS[@]-}"; do
    [[ -n "$snapshot_path" ]] && rm -f "$snapshot_path"
  done
}

ensure_readonly_inputs_unchanged() {
  local runtime_root="$1"
  local idx=0

  for idx in "${!READONLY_INPUT_FILES[@]}"; do
    if ! cmp -s "${READONLY_SNAPSHOTS[$idx]}" "$runtime_root/${READONLY_INPUT_FILES[$idx]}"; then
      die "This phase must not modify ${READONLY_INPUT_FILES[$idx]}; it is read-only input."
    fi
  done
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  require_command sed
  parse_args "$@"

  local runtime_root=""
  local definition_path=""
  local models_path=""
  local output_path=""
  local project_type_code=""
  local prompt_arg=""

  runtime_root="$(ensure_staged_command_runtime)"
  source_class_repo_paths_lib "$runtime_root"
  resolve_sync_repo_helper "$runtime_root"
  resolve_sibling_lister_helper "$runtime_root"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root
  set_artifact_paths
  ensure_required_files "$runtime_root"
  collect_in_flight_plan_sources "$runtime_root"

  definition_path="$runtime_root/$PROJECT_DEFINITION_FILE"
  models_path="$runtime_root/$MODELS_FILE"
  output_path="$runtime_root/$PREREQUISITE_GAPS_FILE"

  project_type_code="$(resolve_project_type_code "$definition_path")"
  resolve_project_classes "$definition_path"

  if [[ "$project_type_code" != "A" && "$project_type_code" != "B" && "$project_type_code" != "C" ]]; then
    fail_project_type_undefined
  fi

  collect_supported_repo_classes
  sync_ready_supported_repo_paths "$definition_path"
  prepare_readonly_inputs "$runtime_root"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  snapshot_readonly_inputs "$runtime_root"
  trap 'cleanup_snapshots' EXIT

  prompt_arg="$(build_prompt "$runtime_root" "$project_type_code")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$runtime_root"
    "${cmd[@]}"
  )

  ensure_readonly_inputs_unchanged "$runtime_root"
}

main "$@"
