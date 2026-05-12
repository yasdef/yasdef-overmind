#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE=""
IMPLEMENTATION_PLAN_FILE=""
REQUIREMENTS_EARS_FILE=""
TECHNICAL_REQUIREMENTS_FILE=""
PREREQUISITE_GAPS_FILE=""
IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE=""

REVIEW_TEMPLATE_FILE=".templates/implementation_plan_semantic_review_TEMPLATE.md"
REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/implementation_plan_semantic_review_rule.md"
QUALITY_GATE_HELPER=".helper/check_implementation_plan_semantic_review_quality.sh"
IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER=".helper/check_implementation_plan_quality.sh"
MODEL_PHASE="implementation_plan_semantic_review"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
READONLY_INPUT_FILES=()
READONLY_SNAPSHOTS=()
APPLICABLE_SURFACE_MAP_FILES=()
PROJECT_CLASSES=()
ACTIVE_REPO_CLASSES=()

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

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

array_contains() {
  local needle="$1"
  shift || true
  local value=""

  for value in "$@"; do
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
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

resolve_project_classes() {
  local definition_path="$1"
  local parsed_classes=""
  local class_name=""
  local normalized_class=""

  PROJECT_CLASSES=()
  ACTIVE_REPO_CLASSES=()

  if ! parsed_classes="$(extract_meta_project_classes "$definition_path" 2>/dev/null)"; then
    die "Unable to parse project_classes from $PROJECT_DEFINITION_FILE"
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
        if [[ "$normalized_class" == "backend" || "$normalized_class" == "frontend" || "$normalized_class" == "mobile" ]]; then
          if ! array_contains "$normalized_class" "${ACTIVE_REPO_CLASSES[@]-}"; then
            ACTIVE_REPO_CLASSES+=("$normalized_class")
          fi
        fi
        ;;
      *)
        die "Unsupported project class in $PROJECT_DEFINITION_FILE: $normalized_class"
        ;;
    esac
  done <<<"$parsed_classes"
}

set_artifact_paths() {
  IMPLEMENTATION_PLAN_FILE="$FEATURE_PATH/implementation_plan.md"
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  TECHNICAL_REQUIREMENTS_FILE="$FEATURE_PATH/technical_requirements.md"
  PREREQUISITE_GAPS_FILE="$FEATURE_PATH/prerequisite_gaps.md"
  IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE="$FEATURE_PATH/implementation_plan_semantic_review.md"
}

collect_applicable_surface_maps() {
  local runtime_root="$1"
  local required_map_path=""
  local class_name=""
  local missing_classes=()

  APPLICABLE_SURFACE_MAP_FILES=()
  for class_name in "${ACTIVE_REPO_CLASSES[@]-}"; do
    case "$class_name" in
      backend)
        required_map_path="$FEATURE_PATH/project_surface_struct_resp_map_backend.md"
        ;;
      frontend)
        required_map_path="$FEATURE_PATH/project_surface_struct_resp_map_frontend.md"
        ;;
      mobile)
        required_map_path="$FEATURE_PATH/project_surface_struct_resp_map_mobile.md"
        ;;
      *)
        continue
        ;;
    esac

    if [[ -f "$runtime_root/$required_map_path" ]]; then
      APPLICABLE_SURFACE_MAP_FILES+=("$required_map_path")
    else
      missing_classes+=("$class_name")
    fi
  done

  if [[ ${#missing_classes[@]} -gt 0 ]]; then
    die "Required surface-map artifacts not found for active repo classes: ${missing_classes[*]}"
  fi
}

prepare_readonly_inputs() {
  READONLY_INPUT_FILES=(
    "$PROJECT_DEFINITION_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$TECHNICAL_REQUIREMENTS_FILE"
    "$PREREQUISITE_GAPS_FILE"
  )
  if [[ ${#APPLICABLE_SURFACE_MAP_FILES[@]} -gt 0 ]]; then
    READONLY_INPUT_FILES+=("${APPLICABLE_SURFACE_MAP_FILES[@]}")
  fi
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$IMPLEMENTATION_PLAN_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$TECHNICAL_REQUIREMENTS_FILE"
    "$PREREQUISITE_GAPS_FILE"
    "$REVIEW_TEMPLATE_FILE"
    "$REVIEW_GOLDEN_EXAMPLE_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$QUALITY_GATE_HELPER"
    "$IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER"
    "$PROJECT_DEFINITION_FILE"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
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

failure_line() {
  printf '%s' "implementation plan semantic review cannot be completed with current plan/requirements/technical inputs. Please provide instructions what to do, or adjust inputs and rerun this phase"
}

success_line() {
  printf '%s' "Implementation plan semantic review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"
}

render_readonly_input_lines() {
  local path=""
  for path in "${READONLY_INPUT_FILES[@]}"; do
    printf '  - %s\n' "$path"
  done
}

render_applicable_surface_map_lines() {
  local surface_map_path=""
  local class_name=""

  for surface_map_path in "${APPLICABLE_SURFACE_MAP_FILES[@]}"; do
    printf '  - %s\n' "$surface_map_path"
  done

  if [[ ${#APPLICABLE_SURFACE_MAP_FILES[@]} -eq 0 ]]; then
    printf '%s\n' "  - none"
  fi
}

render_active_repo_class_lines() {
  local class_name=""

  for class_name in "${ACTIVE_REPO_CLASSES[@]-}"; do
    printf '  - %s\n' "$class_name"
  done

  if [[ ${#ACTIVE_REPO_CLASSES[@]} -eq 0 ]]; then
    printf '%s\n' "  - none"
  fi
}

build_prompt() {
  local runtime_root="$1"
  local failure_msg=""
  local success_msg=""
  local readonly_lines=""
  local surface_map_lines=""
  local active_repo_class_lines=""
  local quality_gate_command="$QUALITY_GATE_HELPER $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
  local implementation_plan_quality_gate_command="$IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER $IMPLEMENTATION_PLAN_FILE"

  failure_msg="$(failure_line)"
  success_msg="$(success_line)"
  readonly_lines="$(render_readonly_input_lines)"
  surface_map_lines="$(render_applicable_surface_map_lines)"
  active_repo_class_lines="$(render_active_repo_class_lines)"

  cat <<EOF_PROMPT
Run optional Step 8.4 implementation-plan semantic review phase for this feature.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this review behavior.
- Use $REVIEW_TEMPLATE_FILE as output structure contract.
- Use $REVIEW_GOLDEN_EXAMPLE_FILE as style contract.
- Read these as input only and do not modify them:
$readonly_lines
- Update only $IMPLEMENTATION_PLAN_FILE and $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE.
- Start by creating/updating $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE with numbered findings and state \'added\' (or \'no_findings: true\' when none).
- If at least one finding exists, present concise summary to user and ask exactly:
  "Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)"
- After user answer, update $IMPLEMENTATION_PLAN_FILE for selected findings and update each finding state to one of: added, applied, rejected, postponed.
- Keep \'added\' only if user answer is incomplete and the finding still needs explicit decision.
- Set review_status complete only when all findings are terminal (applied/rejected/postponed) or no_findings true.
- Do not allow terminal delivered_surface_consumption_unclear or repo_scaffold_readiness_unclear findings with empty resolution_notes.
- Keep plan edits minimal and directly linked to selected findings.
- Before finishing, run this quality gate command: $quality_gate_command
- If completion is not feasible with current inputs or user direction, end with this exact line:
  "$failure_msg"
- If complete, end with this exact last line:
  "$success_msg"

Context:
- ASDLC workspace root: $runtime_root
- Feature root: $FEATURE_PATH
- Mutable plan target: $IMPLEMENTATION_PLAN_FILE
- Mutable semantic review target: $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE
- Read-only project definition source: $PROJECT_DEFINITION_FILE
- Read-only requirements source: $REQUIREMENTS_EARS_FILE
- Read-only technical requirements source: $TECHNICAL_REQUIREMENTS_FILE
- Read-only prerequisite gaps source: $PREREQUISITE_GAPS_FILE
- Active repo classes:
$active_repo_class_lines
- Read-only applicable surface-map artifacts:
$surface_map_lines
- Rule file: $RULE_FILE
- Template file: $REVIEW_TEMPLATE_FILE
- Golden example file: $REVIEW_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_gate_command
- Implementation plan quality gate helper: $IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER
- Implementation plan quality gate command: $implementation_plan_quality_gate_command
EOF_PROMPT
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

run_quality_gate() {
  local runtime_root="$1"
  local helper_path="$runtime_root/$QUALITY_GATE_HELPER"

  if ! "$helper_path" "$IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"; then
    die "Semantic review quality gate failed for: $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
  fi
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  parse_args "$@"

  local runtime_root=""
  local models_path=""
  local review_output_path=""
  local prompt_arg=""

  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root
  set_artifact_paths
  resolve_project_classes "$runtime_root/$PROJECT_DEFINITION_FILE"
  collect_applicable_surface_maps "$runtime_root"
  prepare_readonly_inputs
  ensure_required_files "$runtime_root"

  models_path="$runtime_root/$MODELS_FILE"
  review_output_path="$runtime_root/$IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  snapshot_readonly_inputs "$runtime_root"
  trap 'cleanup_snapshots' EXIT

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

  if [[ ! -f "$review_output_path" ]]; then
    die "Model run did not produce required file: $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
  fi

  ensure_readonly_inputs_unchanged "$runtime_root"
  run_quality_gate "$runtime_root"
  echo "Updated $IMPLEMENTATION_PLAN_FILE"
  echo "Updated $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
}

main "$@"
