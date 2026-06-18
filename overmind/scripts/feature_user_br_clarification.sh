#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
FEATURE_BR_FILE=""
MISSING_DATA_FILE=""
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/user_br_clarification_rule.md"
HELPER_SCRIPT=".helper/check_user_br_clarification_quality.sh"
MODEL_PHASE="user_br_clarification"

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

set_artifact_paths() {
  FEATURE_BR_FILE="$FEATURE_PATH/feature_br_summary.md"
  MISSING_DATA_FILE="$FEATURE_PATH/missing_br_data.md"
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

ensure_feature_summary_exists() {
  local runtime_root="$1"

  if [[ ! -f "$runtime_root/$FEATURE_BR_FILE" ]]; then
    die "Required file not found: $FEATURE_BR_FILE"
  fi
}

missing_data_has_non_rised_items() {
  local missing_data_path="$1"

  awk '
BEGIN {
  in_unresolved_ledger = 0
  has_non_rised = 0
}
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
/^##[[:space:]]+/ {
  heading = trim($0)
  in_unresolved_ledger = (heading ~ /^##[[:space:]]+3\.[[:space:]]+Unresolved[[:space:]]+Items[[:space:]]+Ledger[[:space:]]+\(Rised\)[[:space:]]*$/)
  next
}
{
  if (!in_unresolved_ledger) {
    next
  }

  lowered = tolower(trim($0))

  # Ignore quoted examples and only inspect actual ledger entries.
  if (lowered !~ /^-[[:space:]]*rised_item_[0-9]+:[[:space:]]*/) {
    next
  }

  if (lowered ~ /non-rised|not-rised|rised[[:space:]]*=[[:space:]]*false|rised:[[:space:]]*false/) {
    has_non_rised = 1
    next
  }

  # Any tracked rised_item without explicit rised=true remains unresolved.
  if (lowered !~ /rised[[:space:]]*=[[:space:]]*true/ && lowered !~ /rised:[[:space:]]*true/) {
    has_non_rised = 1
  }
}
END {
  if (has_non_rised) {
    exit 0
  }
  exit 1
}
' "$missing_data_path"
}

ensure_required_files_for_loop() {
  local repo_root="$1"
  local required_paths=(
    "$FEATURE_BR_FILE"
    "$MODELS_FILE"
    "$RULE_FILE"
    "$HELPER_SCRIPT"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$repo_root/$relative_path" ]]; then
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
  local repo_root="$1"
  local gate_command="$HELPER_SCRIPT $FEATURE_BR_FILE"

  cat <<EOF
Run user BR clarification for unresolved business gaps.

Hard constraints:
- Update only $FEATURE_BR_FILE and $MISSING_DATA_FILE.
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for user BR clarification behavior.
- Ask targeted business-only follow-up questions.
- Keep question-state tracking in $MISSING_DATA_FILE using \`rised\` flag only.
- For newly created unresolved ledger items, initialize \`rised=false\`.
- Transition handled items to \`rised=true\` only after the item has actually been discussed with user.
- Write actual answer content only in $FEATURE_BR_FILE.
- Do not duplicate answer text in $MISSING_DATA_FILE.
- Record one pointer-only \`- answers:\` entry in $MISSING_DATA_FILE for each discussed item.
- If multiple questions are discussed in one round, add multiple \`- answers:\` entries in $MISSING_DATA_FILE.
- Rerun $HELPER_SCRIPT after each answer round until completion/stop condition.
- Do not declare phase complete while unresolved loop state remains.
- Treat helper pass as valid only when all tracked \`rised_item_N\` entries are \`rised=true\`.
- When user BR clarification is fully complete, end your final response with this exact last line: "User BR clarification phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Repository root: $repo_root
- Runtime path bindings are authoritative for this invocation.
- Feature artifact root: $FEATURE_PATH
- Target BR artifact: $FEATURE_BR_FILE
- Missing-data artifact: $MISSING_DATA_FILE
- Loop rule file: $RULE_FILE
- Gate helper: $HELPER_SCRIPT
- Gate helper command: $gate_command
EOF
}

main() {
  parse_args "$@"

  local repo_root=""
  repo_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$repo_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths
  ensure_feature_summary_exists "$repo_root"

  local missing_data_path="$repo_root/$MISSING_DATA_FILE"
  if [[ ! -f "$missing_data_path" ]]; then
    die "Required missing-data artifact not found: $MISSING_DATA_FILE. Run .commands/feature_task_to_br.sh for this feature before user BR clarification."
  fi

  if ! missing_data_has_non_rised_items "$missing_data_path"; then
    echo "No non-rised items found in $MISSING_DATA_FILE (all tracked items are rised=true); skipping user BR clarification."
    exit 0
  fi

  ensure_required_files_for_loop "$repo_root"

  local models_path="$repo_root/$MODELS_FILE"
  local prompt_arg=""
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_prompt "$repo_root")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$repo_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$repo_root/$FEATURE_BR_FILE" ]]; then
    die "Model run did not produce required file: $FEATURE_BR_FILE"
  fi

  local helper_status=0
  set +e
  "$repo_root/$HELPER_SCRIPT" "$FEATURE_BR_FILE" >/dev/null 2>&1
  helper_status=$?
  set -e
  if [[ "$helper_status" -eq 2 ]]; then
    die "Business-context helper failed after user BR clarification run."
  fi
  if [[ "$helper_status" -ne 0 ]]; then
    die "Business-context helper reported unresolved user BR clarification state after model run."
  fi

  if missing_data_has_non_rised_items "$repo_root/$MISSING_DATA_FILE"; then
    die "Missing-data loop remains unresolved: $MISSING_DATA_FILE still contains non-rised items."
  fi

  echo "Processed $MISSING_DATA_FILE via user BR clarification."
}

main "$@"
