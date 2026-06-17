#!/usr/bin/env bash
set -euo pipefail
# Stopgap (D6): clears blueprint-era contract drift once per class attach; ongoing drift is the feedback loop's job.

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
PROJECT_PATH_INPUT=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
PROJECT_OUTPUT_FILE="common_contract_definition.md"
MODELS_FILE=".setup/models.md"
MODEL_PHASE="project_contract_reconciliation"
MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
READY_REPO_PATHS=()
READY_REPO_CONTEXT_LINES=()

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
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$PROJECT_PATH_INPUT" ]] || die "Missing required argument: --path <asdlc/projects/<project-id>>."
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
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

collect_ready_repo_paths() {
  local definition_path="$1"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""

  READY_REPO_PATHS=()
  READY_REPO_CONTEXT_LINES=()

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path" 2>/dev/null)"; then
    die "Failed to read meta_info.class_repo_paths from $definition_path."
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path <<<"$entry"
    class_name="$(trim_value "$class_name")"
    normalized_state="$(printf '%s' "$(trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(strip_quotes "$class_path")"
    [[ -n "$class_name" && "$normalized_state" == "ready" ]] || continue

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
    if ! array_contains "$resolved_path" "${READY_REPO_PATHS[@]-}"; then
      READY_REPO_PATHS+=("$resolved_path")
      READY_REPO_CONTEXT_LINES+=("- $class_name: $resolved_path")
    fi
  done <<<"$parsed_entries"

  if [[ ${#READY_REPO_PATHS[@]} -eq 0 ]]; then
    die "No ready repository paths found in meta_info.class_repo_paths."
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

render_ready_repo_context_lines() {
  local line=""
  for line in "${READY_REPO_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

build_prompt() {
  local runtime_root="$1"
  local project_definition_path="$2"
  local target_artifact_path="$3"

  cat <<EOF_PROMPT
Reconcile the project common contract definition against the as-built API for a first attached class.

Hard constraints:
- This is a one-time stopgap for first-attach contract drift only.
- Read the current documented contract from $target_artifact_path.
- Inspect only the ready repository paths listed below as as-built API evidence.
- List mismatches between the documented contract and the as-built API for operator review.
- Ask the operator to approve, reject, or revise each proposed correction before editing.
- Write back only operator-approved corrections to $target_artifact_path.
- If the operator approves no corrections, leave $target_artifact_path unchanged.
- Do not modify $project_definition_path.
- Do not modify any attached repository source files.
- When contract reconciliation is fully complete, end your final response with this exact last line: "Contract reconciliation phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Runtime root: $runtime_root
- ASDLC project root: $PROJECT_ROOT
- Project definition file: $project_definition_path
- Current common contract definition: $target_artifact_path
- Ready repository paths:
$(render_ready_repo_context_lines)
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

commit_contract_if_changed() {
  local project_abs_path="$1"
  local contract_relative_path="$2"
  local target_status=""

  if ! git -C "$project_abs_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Project path must be a git repository to commit contract reconciliation: $project_abs_path"
  fi

  target_status="$(git -C "$project_abs_path" status --porcelain -- "$contract_relative_path")"
  if [[ -n "$target_status" ]]; then
    git -C "$project_abs_path" add -- "$contract_relative_path"
    if git -C "$project_abs_path" diff --cached --quiet -- "$contract_relative_path"; then
      echo "No approved contract reconciliation corrections to commit."
      return 0
    fi
    git -C "$project_abs_path" commit -m "Reconcile common contract with attached repo API" >/dev/null
    echo "Committed $PROJECT_ROOT/$contract_relative_path"
    return 0
  fi

  echo "No approved contract reconciliation corrections to commit."
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command git
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

  collect_ready_repo_paths "$project_definition_path"
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
  commit_contract_if_changed "$runtime_root/$PROJECT_ROOT" "$PROJECT_OUTPUT_FILE"
  echo "Updated $PROJECT_ROOT/$PROJECT_OUTPUT_FILE"
}

main "$@"
