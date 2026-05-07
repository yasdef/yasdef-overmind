#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
FEATURE_BR_FILE=""
REQUIREMENTS_EARS_FILE=""
COMMON_CONTRACT_DEFINITION_FILE=""
FEATURE_CONTRACT_DELTA_FILE=""
FEATURE_CONTRACT_TEMPLATE_FILE=".templates/feature_contract_delta_TEMPLATE.md"
FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE=".golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/feature_contract_delta_rule.md"
QUALITY_GATE_HELPER=".helper/check_feature_contract_delta_quality.sh"
CROSS_CLASS_PEER_TRIGGER_HELPER=".helper/check_cross_class_peer_trigger.sh"
MODEL_PHASE="feature_contract_delta"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()

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
}

set_artifact_paths() {
  FEATURE_BR_FILE="$FEATURE_PATH/feature_br_summary.md"
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  FEATURE_CONTRACT_DELTA_FILE="$FEATURE_PATH/feature_contract_delta.md"
  COMMON_CONTRACT_DEFINITION_FILE="$PROJECT_ROOT/common_contract_definition.md"
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$FEATURE_BR_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$COMMON_CONTRACT_DEFINITION_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$FEATURE_CONTRACT_TEMPLATE_FILE"
    "$FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE"
    "$QUALITY_GATE_HELPER"
    "$CROSS_CLASS_PEER_TRIGGER_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

extract_meta_value() {
  local feature_br_path="$1"
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
/^##[[:space:]]+/ {
  heading = trim($0)
  in_meta = (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/)
  next
}
{
  if (!in_meta) {
    next
  }

  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
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
' "$feature_br_path"
}

extract_project_type_code() {
  local feature_br_path="$1"
  local value=""

  if ! value="$(extract_meta_value "$feature_br_path" "project_type_code")"; then
    die "Missing key project_type_code in ## 1. Document Meta: $FEATURE_BR_FILE"
  fi

  if [[ -z "$value" ]]; then
    die "project_type_code must not be empty in $FEATURE_BR_FILE"
  fi

  printf '%s' "$value"
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

build_prompt() {
  local runtime_root="$1"
  local project_type_code="$2"
  local quality_command="$QUALITY_GATE_HELPER $FEATURE_CONTRACT_DELTA_FILE"
  local project_definition_path="$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"

  cat <<EOF
Define feature-level shared contract delta from EARS requirements and common contract baseline.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this phase.
- Use $FEATURE_CONTRACT_TEMPLATE_FILE as output structure contract.
- Use $FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE as style contract.
- Read these as input only and do not modify them:
  - $FEATURE_BR_FILE
  - $REQUIREMENTS_EARS_FILE
  - $COMMON_CONTRACT_DEFINITION_FILE
- Update only $FEATURE_CONTRACT_DELTA_FILE.
- Keep output focused on feature-level contract additions/changes vs baseline.
- Keep one independent delta per \`### Delta N\` block and add \`Delta 2+\` blocks when multiple deltas exist.
- Before finishing, ensure output can pass this quality gate command: $quality_command
- Evaluate whether gate compliance is feasible with current inputs and constraints.
- If gate compliance is not feasible, stop and end with this exact line:
  "feature contract delta gate cannot pass with current EARS/common-contract inputs. Please provide instructions what to do, or adjust requirements and rerun this phase"
- If quality gate is feasible with current inputs and passed, end your final response with this exact last line:
  "Feature contract delta phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- ASDLC workspace root: $runtime_root
- Project root: $PROJECT_ROOT
- Feature root: $FEATURE_PATH
- Project type code: $project_type_code
- Feature BR source: $FEATURE_BR_FILE
- Requirements EARS source: $REQUIREMENTS_EARS_FILE
- Common contract baseline source: $COMMON_CONTRACT_DEFINITION_FILE
- Target artifact: $FEATURE_CONTRACT_DELTA_FILE
- Rule file: $RULE_FILE
- Template file: $FEATURE_CONTRACT_TEMPLATE_FILE
- Golden example file: $FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
- Cross-class peer trigger helper command: $CROSS_CLASS_PEER_TRIGGER_HELPER $project_definition_path
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

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  parse_args "$@"

  local runtime_root=""
  local feature_br_path=""
  local requirements_ears_path=""
  local common_contract_path=""
  local output_path=""
  local models_path=""
  local project_type_code=""
  local prompt_arg=""
  local before_feature_br=""
  local before_requirements=""
  local before_common_contract=""

  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root "$runtime_root"
  set_artifact_paths
  ensure_required_files "$runtime_root"

  feature_br_path="$runtime_root/$FEATURE_BR_FILE"
  requirements_ears_path="$runtime_root/$REQUIREMENTS_EARS_FILE"
  common_contract_path="$runtime_root/$COMMON_CONTRACT_DEFINITION_FILE"
  output_path="$runtime_root/$FEATURE_CONTRACT_DELTA_FILE"
  models_path="$runtime_root/$MODELS_FILE"

  project_type_code="$(extract_project_type_code "$feature_br_path")"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_feature_br="$(mktemp)"
  before_requirements="$(mktemp)"
  before_common_contract="$(mktemp)"
  cp "$feature_br_path" "$before_feature_br"
  cp "$requirements_ears_path" "$before_requirements"
  cp "$common_contract_path" "$before_common_contract"
  trap '[[ -n "${before_feature_br:-}" ]] && rm -f "$before_feature_br"; [[ -n "${before_requirements:-}" ]] && rm -f "$before_requirements"; [[ -n "${before_common_contract:-}" ]] && rm -f "$before_common_contract"' EXIT

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

  if [[ ! -f "$output_path" ]]; then
    die "Model run did not produce required file: $FEATURE_CONTRACT_DELTA_FILE"
  fi

  ensure_file_unchanged "$before_feature_br" "$feature_br_path" "$FEATURE_BR_FILE"
  ensure_file_unchanged "$before_requirements" "$requirements_ears_path" "$REQUIREMENTS_EARS_FILE"
  ensure_file_unchanged "$before_common_contract" "$common_contract_path" "$COMMON_CONTRACT_DEFINITION_FILE"
  echo "Updated $FEATURE_CONTRACT_DELTA_FILE"
}

main "$@"
