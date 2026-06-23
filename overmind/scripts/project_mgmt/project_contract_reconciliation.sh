#!/usr/bin/env bash
set -euo pipefail
# Stopgap (D6): clears blueprint-era contract drift once per class attach; ongoing drift is the feedback loop's job.

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
PROJECT_PATH_INPUT=""
TARGET_CLASSES=()
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
PROJECT_OUTPUT_FILE="common_contract_definition.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/project_contract_reconciliation_rule.md"
QUALITY_GATE_HELPER=".helper/check_common_contract_definition_quality.sh"
MODEL_PHASE="project_contract_reconciliation"
MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
READY_REPO_PATHS=()
READY_REPO_CONTEXT_LINES=()
OUT_OF_SCOPE_CLASS_CONTEXT_LINES=()

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

strip_quotes() {
  local value="$1"
  value="$(trim_value "$value")"
  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$(trim_value "$value")"
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

normalize_project_path() {
  local raw_path="${1:-}"
  local normalized="$raw_path"

  normalized="${normalized#./}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done

  if [[ -z "$normalized" ]]; then
    die "project path must not be empty."
  fi

  printf '%s' "$normalized"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --path."
      PROJECT_PATH_INPUT="$(normalize_project_path "$1")"
      ;;
    --class)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --class."
      TARGET_CLASSES+=("$(printf '%s' "$(trim_value "$1")" | tr '[:upper:]' '[:lower:]')")
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$PROJECT_PATH_INPUT" ]] || die "Missing required argument: --path <asdlc/projects/<project-id>>."
  [[ "${#TARGET_CLASSES[@]}" -gt 0 ]] || die "Missing required argument: --class <class> (repeatable)."
}

source_class_repo_paths_lib() {
  local runtime_root="$1"
  local lib_path="$runtime_root/common_libs/class_repo_paths.sh"
  [[ -f "$lib_path" ]] || die "Required command lib not found: common_libs/class_repo_paths.sh"
  # shellcheck source=/dev/null
  source "$lib_path"
}

resolve_project_root() {
  local runtime_root="$1"
  local input_path="$2"
  local candidate_path=""
  local resolved_path=""
  local relative_after_projects=""

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
  "$runtime_root/projects"/*)
    ;;
  *)
    die "Project path must resolve to asdlc/projects/<project-id>: $resolved_path"
    ;;
  esac

  relative_after_projects="${resolved_path#"$runtime_root/projects/"}"
  if [[ -z "$relative_after_projects" || "$relative_after_projects" == */* ]]; then
    die "Project path must resolve to asdlc/projects/<project-id>: $resolved_path"
  fi

  PROJECT_ROOT="projects/$relative_after_projects"
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
    "$PROJECT_ROOT/$PROJECT_OUTPUT_FILE"
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

collect_target_repo_paths() {
  local definition_path="$1"
  local class_name=""
  local entry=""
  local class_state=""
  local class_path=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""

  READY_REPO_PATHS=()
  READY_REPO_CONTEXT_LINES=()

  for class_name in "${TARGET_CLASSES[@]}"; do
    if ! entry="$(class_repo_paths_find_entry "$definition_path" "$class_name" 2>/dev/null)"; then
      die "Target class '$class_name' not found in meta_info.class_repo_paths: $definition_path"
    fi
    IFS='|' read -r class_state class_path <<<"$entry"
    normalized_state="$(printf '%s' "$(trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(strip_quotes "$class_path")"

    if [[ "$normalized_state" != "ready" ]]; then
      die "Target class '$class_name' is not ready (state: '$normalized_state'); cannot reconcile."
    fi
    if [[ -z "$normalized_path" ]]; then
      die "Repo path for class '$class_name' is marked ready but path is empty in $definition_path."
    fi
    if [[ ! -d "$normalized_path" ]]; then
      die "Repo path for class '$class_name' does not exist or is not a directory: $normalized_path"
    fi
    if [[ ! -e "$normalized_path/.git" ]]; then
      die "Repo path for class '$class_name' is not a git repository: $normalized_path"
    fi
    if ! resolved_path="$(cd "$normalized_path" && pwd -P)"; then
      die "Failed to resolve repo path for class '$class_name': $normalized_path"
    fi
    READY_REPO_CONTEXT_LINES+=("- $class_name: $resolved_path")
    if ! array_contains "$resolved_path" "${READY_REPO_PATHS[@]-}"; then
      READY_REPO_PATHS+=("$resolved_path")
    fi
  done

  if [[ ${#READY_REPO_PATHS[@]} -eq 0 ]]; then
    die "No target repository paths resolved from meta_info.class_repo_paths."
  fi
}

collect_out_of_scope_classes() {
  local definition_path="$1"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local normalized_state=""

  OUT_OF_SCOPE_CLASS_CONTEXT_LINES=()

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path" 2>/dev/null)"; then
    die "Failed to read meta_info.class_repo_paths from $definition_path."
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state _ <<<"$entry"
    class_name="$(printf '%s' "$(trim_value "$class_name")" | tr '[:upper:]' '[:lower:]')"
    normalized_state="$(printf '%s' "$(trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    [[ -n "$class_name" ]] || continue
    array_contains "$class_name" "${TARGET_CLASSES[@]-}" && continue
    OUT_OF_SCOPE_CLASS_CONTEXT_LINES+=("- $class_name ($normalized_state)")
  done <<<"$parsed_entries"
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

render_ready_repo_context_lines() {
  local line=""
  for line in "${READY_REPO_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

render_unique_repo_paths() {
  local repo_path=""
  for repo_path in "${READY_REPO_PATHS[@]}"; do
    printf '%s\n' "- $repo_path"
  done
}

render_out_of_scope_class_lines() {
  if [[ ${#OUT_OF_SCOPE_CLASS_CONTEXT_LINES[@]} -eq 0 ]]; then
    printf '%s\n' "- none"
    return 0
  fi
  local line=""
  for line in "${OUT_OF_SCOPE_CLASS_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

build_prompt() {
  local runtime_root="$1"
  local project_definition_path="$2"
  local target_artifact_path="$3"
  local quality_command=""
  printf -v quality_command "%q %q" "$QUALITY_GATE_HELPER" "$target_artifact_path"

  cat <<EOF_PROMPT
Reconcile the project common contract definition against the as-built API for a first attached class.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for all reconciliation behavior: scope, read-only inputs, the write-back rule, and the quality-gate repair loop.
- If you change the contract, run the quality gate command and make it pass before finishing: $quality_command
- If the gate cannot pass with the available evidence, stop and end with this exact line:
  "contract reconciliation gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust inputs and rerun this phase"
- When contract reconciliation is fully complete, end your final response with this exact last line: "Contract reconciliation phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Runtime root: $runtime_root
- ASDLC project root: $PROJECT_ROOT
- Project definition file: $project_definition_path
- Current common contract definition: $target_artifact_path
- Rule file: $RULE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
- Unique repositories to inspect (scan each path once):
$(render_unique_repo_paths)
- In-scope class-to-repository mappings:
$(render_ready_repo_context_lines)
- Out-of-scope classes (do not challenge their contract surface):
$(render_out_of_scope_class_lines)
EOF_PROMPT
}

ensure_file_unchanged() {
  local before_snapshot="$1"
  local target_path="$2"
  local relative_name="$3"

  if ! cmp -s "$before_snapshot" "$target_path"; then
    die "Contract reconciliation must not modify $relative_name; it is read-only input."
  fi
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  parse_args "$@"

  local runtime_root=""
  local project_definition_path=""
  local target_artifact_path=""
  local models_path=""
  local prompt_arg=""
  local before_project_definition=""

  runtime_root="$(ensure_staged_command_runtime)"
  source_class_repo_paths_lib "$runtime_root"
  resolve_project_root "$runtime_root" "$PROJECT_PATH_INPUT"
  ensure_required_files "$runtime_root"

  project_definition_path="$runtime_root/$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  target_artifact_path="$runtime_root/$PROJECT_ROOT/$PROJECT_OUTPUT_FILE"
  models_path="$runtime_root/$MODELS_FILE"

  collect_target_repo_paths "$project_definition_path"
  collect_out_of_scope_classes "$project_definition_path"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_project_definition="$(mktemp)"
  cp "$project_definition_path" "$before_project_definition"
  trap '[[ -n "${before_project_definition:-}" ]] && rm -f "$before_project_definition"' EXIT

  prompt_arg="$(build_prompt "$runtime_root" "$PROJECT_ROOT/$PROJECT_DEFINITION_FILE" "$PROJECT_ROOT/$PROJECT_OUTPUT_FILE")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$runtime_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$target_artifact_path" ]]; then
    die "Model run did not leave required file in place: $PROJECT_ROOT/$PROJECT_OUTPUT_FILE"
  fi

  ensure_file_unchanged "$before_project_definition" "$project_definition_path" "$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  # The reconciled contract is left in the working tree; the orchestrator commits
  # the whole reconciliation/attach unit (definition + contract + markers) after
  # the operator confirms (project_add_feature_e2e.sh: commit_reconciliation_unit).
  echo "Updated $PROJECT_ROOT/$PROJECT_OUTPUT_FILE"
}

main "$@"
