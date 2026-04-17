#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
IMPLEMENTATION_PLAN_FILE=""
REQUIREMENTS_EARS_FILE=""
TECHNICAL_REQUIREMENTS_FILE=""
PREREQUISITE_GAPS_FILE=""
IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE=""

REVIEW_TEMPLATE_FILE=".templates/implementation_plan_semantic_review_TEMPLATE.md"
REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/implementation_plan_semantic_review_rule.md"
MODEL_PHASE="implementation_plan_semantic_review"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
READONLY_INPUT_FILES=()
READONLY_SNAPSHOTS=()

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

  if ! git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "ASDLC workspace is not a git repository: $parent_dir"
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

set_artifact_paths() {
  IMPLEMENTATION_PLAN_FILE="$FEATURE_PATH/implementation_plan.md"
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  TECHNICAL_REQUIREMENTS_FILE="$FEATURE_PATH/technical_requirements.md"
  PREREQUISITE_GAPS_FILE="$FEATURE_PATH/prerequisite_gaps.md"
  IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE="$FEATURE_PATH/implementation_plan_semantic_review.md"
}

prepare_readonly_inputs() {
  READONLY_INPUT_FILES=(
    "$REQUIREMENTS_EARS_FILE"
    "$TECHNICAL_REQUIREMENTS_FILE"
    "$PREREQUISITE_GAPS_FILE"
  )
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

build_prompt() {
  local runtime_root="$1"
  local failure_msg=""
  local success_msg=""
  local readonly_lines=""

  failure_msg="$(failure_line)"
  success_msg="$(success_line)"
  readonly_lines="$(render_readonly_input_lines)"

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
- Keep plan edits minimal and directly linked to selected findings.
- If completion is not feasible with current inputs or user direction, end with this exact line:
  "$failure_msg"
- If complete, end with this exact last line:
  "$success_msg"

Context:
- ASDLC workspace root: $runtime_root
- Feature root: $FEATURE_PATH
- Mutable plan target: $IMPLEMENTATION_PLAN_FILE
- Mutable semantic review target: $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE
- Read-only requirements source: $REQUIREMENTS_EARS_FILE
- Read-only technical requirements source: $TECHNICAL_REQUIREMENTS_FILE
- Read-only prerequisite gaps source: $PREREQUISITE_GAPS_FILE
- Rule file: $RULE_FILE
- Template file: $REVIEW_TEMPLATE_FILE
- Golden example file: $REVIEW_GOLDEN_EXAMPLE_FILE
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

commit_output_if_changed() {
  local runtime_root="$1"
  local -a commit_paths=(
    "$IMPLEMENTATION_PLAN_FILE"
    "$IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
  )

  if ! git -C "$runtime_root" add -- "${commit_paths[@]}"; then
    die "Failed to stage semantic-review outputs."
  fi

  if git -C "$runtime_root" diff --cached --quiet -- "${commit_paths[@]}"; then
    return 0
  fi

  if ! git -C "$runtime_root" commit -m "Review and apply implementation plan semantic findings" -- "${commit_paths[@]}" >/dev/null 2>&1; then
    die "Failed to commit semantic-review outputs."
  fi
}

main() {
  require_command git
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
  set_artifact_paths
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
  commit_output_if_changed "$runtime_root"
  echo "Updated $IMPLEMENTATION_PLAN_FILE"
  echo "Updated $IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_FILE"
}

main "$@"
