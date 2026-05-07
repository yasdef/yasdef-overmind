#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
USER_BR_INPUT_FILE=""
REQUIREMENTS_EARS_FILE=""
REQUIREMENTS_EARS_REVIEW_FILE=""
REVIEW_TEMPLATE_FILE=".templates/requirements_ears_review_TEMPLATE.md"
REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/requirements_ears_review_rule.md"
QUALITY_GATE_HELPER=".helper/check_requirements_ears_review_quality.sh"
MODEL_PHASE="requirements_ears_review"

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

set_artifact_paths() {
  USER_BR_INPUT_FILE="$FEATURE_PATH/user_br_input.md"
  REQUIREMENTS_EARS_FILE="$FEATURE_PATH/requirements_ears.md"
  REQUIREMENTS_EARS_REVIEW_FILE="$FEATURE_PATH/requirements_ears_review.md"
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$USER_BR_INPUT_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$REVIEW_TEMPLATE_FILE"
    "$REVIEW_GOLDEN_EXAMPLE_FILE"
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
  local quality_command="$QUALITY_GATE_HELPER $REQUIREMENTS_EARS_REVIEW_FILE"

  cat <<EOF
Run the optional requirements_ears extra review phase for this feature.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this review behavior.
- Use $REVIEW_TEMPLATE_FILE as output structure contract.
- Use $REVIEW_GOLDEN_EXAMPLE_FILE as style contract.
- Treat $USER_BR_INPUT_FILE as read-only source input; do not modify it.
- Update only $REQUIREMENTS_EARS_FILE and $REQUIREMENTS_EARS_REVIEW_FILE.
- Create or update $REQUIREMENTS_EARS_REVIEW_FILE as the durable findings ledger for this phase.
- Compare $REQUIREMENTS_EARS_FILE against $USER_BR_INPUT_FILE for material business gaps only.
- Ask the user about one finding at a time, highest severity first.
- For each active finding, show the finding and recommendation explicitly before asking for a decision:
  "Here is the finding: <concise gap summary for the current finding>"
  "I would recommend: <exact recommended change for this finding>"
  "Should I add recommended changes? Please answer yes/no or provide your answer."
- Keep finding state synchronized with the actual decision history in $REQUIREMENTS_EARS_REVIEW_FILE.
- Apply only minimal EARS changes needed to resolve accepted findings.
- Preserve already handled findings in the review ledger; do not delete them.
- Set \`review_status: complete\` only when no findings remain in \`state: escalated\`.
- If there are no material findings, create $REQUIREMENTS_EARS_REVIEW_FILE with \`review_status: complete\` and \`- no_findings: true\`.
- Before finishing, ensure the output can pass this quality gate command: $quality_command
- If review completion is not feasible with the current BR/EARS input or user decisions, stop and end with this exact line:
  "based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase"
- If the phase is complete and the quality gate is feasible and passed, end your final response with this exact last line: "requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- ASDLC workspace root: $runtime_root
- Runtime path bindings are authoritative for this invocation.
- Feature artifact root: $FEATURE_PATH
- Read-only user BR input source: $USER_BR_INPUT_FILE
- Mutable requirements EARS target: $REQUIREMENTS_EARS_FILE
- Mutable review ledger target: $REQUIREMENTS_EARS_REVIEW_FILE
- Rule file: $RULE_FILE
- Template file: $REVIEW_TEMPLATE_FILE
- Golden example file: $REVIEW_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
EOF
}

ensure_user_br_input_unchanged() {
  local before_snapshot="$1"
  local user_br_input_path="$2"

  if ! cmp -s "$before_snapshot" "$user_br_input_path"; then
    die "Requirements EARS extra review must not modify $USER_BR_INPUT_FILE; it is read-only input."
  fi
}

main() {
  require_command awk
  require_command cmp
  parse_args "$@"

  local runtime_root=""
  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths

  local user_br_input_path=""
  local review_path=""
  local models_path=""
  local prompt_arg=""
  local before_snapshot=""

  ensure_required_files "$runtime_root"

  user_br_input_path="$runtime_root/$USER_BR_INPUT_FILE"
  review_path="$runtime_root/$REQUIREMENTS_EARS_REVIEW_FILE"
  models_path="$runtime_root/$MODELS_FILE"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_snapshot="$(mktemp)"
  cp "$user_br_input_path" "$before_snapshot"
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

  if [[ ! -f "$review_path" ]]; then
    die "Model run did not produce required file: $REQUIREMENTS_EARS_REVIEW_FILE"
  fi

  ensure_user_br_input_unchanged "$before_snapshot" "$user_br_input_path"
  echo "Updated $REQUIREMENTS_EARS_FILE"
  echo "Updated $REQUIREMENTS_EARS_REVIEW_FILE"
}

main "$@"
