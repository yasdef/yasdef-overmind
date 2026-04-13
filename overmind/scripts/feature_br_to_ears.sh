#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
FEATURE_BR_FILE=""
REQUIREMENTS_EARS_FILE=""
EARS_TEMPLATE_FILE=".templates/reqirements_ears_TEMPLATE.md"
EARS_GOLDEN_EXAMPLE_FILE=".golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/br_to_ears.md"
QUALITY_GATE_HELPER=".helper/check_requirements_ears_quality.sh"
READINESS_GATE_SCRIPT=".commands/feature_br_check_ears_readiness.sh"
MODEL_PHASE="br_to_ears"

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
  FEATURE_BR_FILE="$FEATURE_PATH/feature_br_summary.md"
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$FEATURE_BR_FILE"
    "$EARS_TEMPLATE_FILE"
    "$EARS_GOLDEN_EXAMPLE_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$QUALITY_GATE_HELPER"
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

ensure_ready_to_ears() {
  local feature_br_path="$1"
  local readiness_value=""

  if ! readiness_value="$(extract_meta_value "$feature_br_path" "ready_to_ears")"; then
    die "Missing key ready_to_ears in ## 1. Document Meta: $FEATURE_BR_FILE. Run $READINESS_GATE_SCRIPT first."
  fi

  if [[ "$readiness_value" != "true" ]]; then
    die "Expected ready_to_ears: true in $FEATURE_BR_FILE. Run $READINESS_GATE_SCRIPT first."
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

build_prompt() {
  local runtime_root="$1"
  local quality_command="$QUALITY_GATE_HELPER $REQUIREMENTS_EARS_FILE"

  cat <<EOF
Convert BR summary into EARS requirements for this feature.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for BR-to-EARS conversion behavior.
- Use $EARS_TEMPLATE_FILE as output structure contract.
- Use $EARS_GOLDEN_EXAMPLE_FILE as style contract.
- Read $FEATURE_BR_FILE as input only; do not modify it.
- Update only $REQUIREMENTS_EARS_FILE.
- Produce deterministic, testable EARS criteria with SHALL statements.
- Keep output business-facing and implementation-agnostic.
- Before finishing, ensure the output can pass this quality gate command: $quality_command
- Evaluate whether gate compliance is feasible with current BR input and constraints.
- If gate compliance is not feasible, stop and end with this exact line:
  "based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase"
- If quality gate is feasible with the current BR input and passed, end your final response with this exact last line: "BR->requirement-EARS phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- ASDLC workspace root: $runtime_root
- Runtime path bindings are authoritative for this invocation.
- Feature artifact root: $FEATURE_PATH
- Read-only BR summary source: $FEATURE_BR_FILE
- Target EARS artifact: $REQUIREMENTS_EARS_FILE
- Rule file: $RULE_FILE
- Template file: $EARS_TEMPLATE_FILE
- Golden example file: $EARS_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
EOF
}

ensure_br_summary_unchanged() {
  local before_snapshot="$1"
  local feature_br_path="$2"

  if ! cmp -s "$before_snapshot" "$feature_br_path"; then
    die "Step 3 must not modify $FEATURE_BR_FILE; it is read-only input."
  fi
}

commit_requirements_if_changed() {
  local runtime_root="$1"

  if ! git -C "$runtime_root" add -- "$REQUIREMENTS_EARS_FILE"; then
    die "Failed to stage $REQUIREMENTS_EARS_FILE."
  fi

  if git -C "$runtime_root" diff --cached --quiet -- "$REQUIREMENTS_EARS_FILE"; then
    return 0
  fi

  if ! git -C "$runtime_root" commit -m "Generate overmind requirements ears" -- "$REQUIREMENTS_EARS_FILE" >/dev/null 2>&1; then
    die "Failed to commit $REQUIREMENTS_EARS_FILE."
  fi
}

main() {
  require_command git
  require_command awk
  require_command cmp
  parse_args "$@"

  local runtime_root=""
  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths

  local feature_br_path=""
  local requirements_path=""
  local models_path=""
  local prompt_arg=""
  local before_snapshot=""

  ensure_required_files "$runtime_root"

  feature_br_path="$runtime_root/$FEATURE_BR_FILE"
  requirements_path="$runtime_root/$REQUIREMENTS_EARS_FILE"
  models_path="$runtime_root/$MODELS_FILE"
  ensure_ready_to_ears "$feature_br_path"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_snapshot="$(mktemp)"
  cp "$feature_br_path" "$before_snapshot"
  trap '[[ -n "${before_snapshot:-}" ]] && rm -f "$before_snapshot"' EXIT

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

  if [[ ! -f "$requirements_path" ]]; then
    die "Model run did not produce required file: $REQUIREMENTS_EARS_FILE"
  fi

  ensure_br_summary_unchanged "$before_snapshot" "$feature_br_path"
  commit_requirements_if_changed "$runtime_root"
  echo "Updated $REQUIREMENTS_EARS_FILE"
}

main "$@"
