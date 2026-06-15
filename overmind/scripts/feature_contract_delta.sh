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
READY_REPO_PATHS=()
READY_REPO_CONTEXT_LINES=()
SYNC_REPO_TO_DEFAULT_BRANCH=""
LIST_COMMITTED_SIBLING_FEATURES=""
PENDING_CONTRACT_DELTA_FILES=()
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
    "$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
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

collect_ready_repo_paths() {
  local definition_path="$1"
  local entry=""
  local class_name=""
  local resolved_path=""
  local ready_paths=""

  READY_REPO_PATHS=()
  READY_REPO_CONTEXT_LINES=()

  if ! ready_paths="$(class_repo_paths_collect_ready_paths "$definition_path" 2>&1)"; then
    die "$ready_paths"
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name resolved_path <<<"$entry"
    "$SYNC_REPO_TO_DEFAULT_BRANCH" "$resolved_path"
    READY_REPO_PATHS+=("$resolved_path")
    READY_REPO_CONTEXT_LINES+=("- $class_name: $resolved_path")
  done <<<"$ready_paths"
}

collect_pending_contract_delta_sources() {
  local runtime_root="$1"
  local feature_abs_path="$runtime_root/$FEATURE_PATH"
  local sibling_features=""
  local sibling_folder=""
  local relative_path=""

  PENDING_CONTRACT_DELTA_FILES=()

  if ! sibling_features="$("$LIST_COMMITTED_SIBLING_FEATURES" --feature_path "$feature_abs_path" 2>&1)"; then
    echo "$sibling_features" >&2
    exit 1
  fi

  while IFS= read -r sibling_folder; do
    [[ -n "$sibling_folder" ]] || continue
    relative_path="$PROJECT_ROOT/$sibling_folder/feature_contract_delta.md"
    if [[ -f "$runtime_root/$relative_path" ]]; then
      PENDING_CONTRACT_DELTA_FILES+=("$relative_path")
    fi
  done <<<"$sibling_features"
}

prepare_readonly_inputs() {
  local pending_file=""

  READONLY_INPUT_FILES=(
    "$FEATURE_BR_FILE"
    "$REQUIREMENTS_EARS_FILE"
    "$COMMON_CONTRACT_DEFINITION_FILE"
  )

  if [[ ${#PENDING_CONTRACT_DELTA_FILES[@]} -gt 0 ]]; then
    for pending_file in "${PENDING_CONTRACT_DELTA_FILES[@]}"; do
      READONLY_INPUT_FILES+=("$pending_file")
    done
  fi
}

render_ready_repo_context_lines() {
  local line=""
  if [[ ${#READY_REPO_CONTEXT_LINES[@]} -eq 0 ]]; then
    printf '%s\n' "- none"
    return 0
  fi

  for line in "${READY_REPO_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

render_readonly_input_lines() {
  local path=""
  for path in "${READONLY_INPUT_FILES[@]}"; do
    printf '  - %s\n' "$path"
  done
}

render_pending_contract_delta_context_lines() {
  local path=""
  local folder_and_file=""

  if [[ ${#PENDING_CONTRACT_DELTA_FILES[@]} -eq 0 ]]; then
    printf '%s\n' "- none"
    return 0
  fi

  for path in "${PENDING_CONTRACT_DELTA_FILES[@]}"; do
    folder_and_file="${path#"$PROJECT_ROOT/"}"
    printf '%s\n' "- Pending contract delta source: $folder_and_file"
  done
}

build_prompt() {
  local runtime_root="$1"
  local quality_command="$QUALITY_GATE_HELPER $FEATURE_CONTRACT_DELTA_FILE"
  local project_definition_path="$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  local repo_context_lines=""
  local readonly_input_lines=""
  local pending_contract_delta_lines=""

  repo_context_lines="$(render_ready_repo_context_lines)"
  readonly_input_lines="$(render_readonly_input_lines)"
  pending_contract_delta_lines="$(render_pending_contract_delta_context_lines)"

  cat <<EOF
Define feature-level shared contract delta from EARS requirements and common contract baseline.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for this phase.
- Use $FEATURE_CONTRACT_TEMPLATE_FILE as output structure contract.
- Use $FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE as style contract.
- Read these as input only and do not modify them:
$readonly_input_lines
- Update only $FEATURE_CONTRACT_DELTA_FILE.
- Draft $FEATURE_CONTRACT_DELTA_FILE before running any quality gate command.
- Use this quality gate command before finalizing: $quality_command
- Handle quality gate outcomes exactly as defined by $RULE_FILE.

Context:
- ASDLC workspace root: $runtime_root
- Project root: $PROJECT_ROOT
- Feature root: $FEATURE_PATH
- Feature BR source: $FEATURE_BR_FILE
- Requirements EARS source: $REQUIREMENTS_EARS_FILE
- Common contract baseline source: $COMMON_CONTRACT_DEFINITION_FILE
- Repositories to scan (meta_info.class_repo_paths with state=ready):
$repo_context_lines
- Pending sibling contract deltas:
$pending_contract_delta_lines
- Pending contract delta source labels are relative to $PROJECT_ROOT; open the matching read-only input at $PROJECT_ROOT/<folder>/feature_contract_delta.md.
- Target artifact: $FEATURE_CONTRACT_DELTA_FILE
- Rule file: $RULE_FILE
- Template file: $FEATURE_CONTRACT_TEMPLATE_FILE
- Golden example file: $FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
- Cross-class peer trigger helper command: $CROSS_CLASS_PEER_TRIGGER_HELPER $project_definition_path
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
  parse_args "$@"

  local runtime_root=""
  local feature_br_path=""
  local requirements_ears_path=""
  local common_contract_path=""
  local project_definition_path=""
  local output_path=""
  local models_path=""
  local prompt_arg=""

  runtime_root="$(ensure_staged_command_runtime)"
  source_class_repo_paths_lib "$runtime_root"
  resolve_sync_repo_helper "$runtime_root"
  resolve_sibling_lister_helper "$runtime_root"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root "$runtime_root"
  set_artifact_paths
  ensure_required_files "$runtime_root"

  feature_br_path="$runtime_root/$FEATURE_BR_FILE"
  requirements_ears_path="$runtime_root/$REQUIREMENTS_EARS_FILE"
  common_contract_path="$runtime_root/$COMMON_CONTRACT_DEFINITION_FILE"
  project_definition_path="$runtime_root/$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  output_path="$runtime_root/$FEATURE_CONTRACT_DELTA_FILE"
  models_path="$runtime_root/$MODELS_FILE"

  collect_ready_repo_paths "$project_definition_path"
  collect_pending_contract_delta_sources "$runtime_root"
  prepare_readonly_inputs
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  snapshot_readonly_inputs "$runtime_root"
  trap cleanup_snapshots EXIT

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

  if [[ ! -f "$output_path" ]]; then
    die "Model run did not produce required file: $FEATURE_CONTRACT_DELTA_FILE"
  fi

  ensure_readonly_inputs_unchanged "$runtime_root"
  echo "Updated $FEATURE_CONTRACT_DELTA_FILE"
}

main "$@"
