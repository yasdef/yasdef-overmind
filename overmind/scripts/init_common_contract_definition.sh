#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH_INPUT=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
PROJECT_OUTPUT_FILE="common_contract_definition.md"
COMMON_CONTRACT_TEMPLATE_FILE=".templates/common_contract_definition_TEMPLATE.md"
COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE=".golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/common_contract_definition_rule.md"
QUALITY_GATE_HELPER=".helper/check_common_contract_definition_quality.sh"
MODEL_PHASE="common_contract_definition"
RUNTIME_ROOT=""

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
REPO_PATHS=()
REPO_CONTEXT_LINES=()

die() {
  echo "ERROR: $*" >&2
  exit 1
}

fail_project_type_a_not_supported() {
  echo "project type A is not supported yet: MCP extraction for common contract definition is unavailable" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value
  value="$(trim_value "$1")"
  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

array_contains() {
  local needle="$1"
  shift
  local item=""

  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --path."
      PROJECT_PATH_INPUT="$1"
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$PROJECT_PATH_INPUT" ]] || die "Missing required argument: --path <asdlc/projects/<project-id>>."
}

resolve_runtime_root() {
  local script_dir=""
  local parent_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    die "Failed to resolve script directory."
  fi

  parent_dir="$(dirname "$script_dir")"
  if [[ "$(basename "$script_dir")" == ".commands" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    RUNTIME_ROOT="$parent_dir"
    return 0
  fi

  die "init asdlc repo first, run this script only from asldc/.commands"
}

ensure_required_files() {
  local repo_root="$1"
  local required_paths=(
    "$MODELS_FILE"
    "$RULE_FILE"
    "$COMMON_CONTRACT_TEMPLATE_FILE"
    "$COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE"
    "$QUALITY_GATE_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$repo_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

resolve_project_root() {
  local input_path="$1"
  local runtime_root="$2"
  local project_root=""
  local projects_root=""
  local relative_from_projects=""

  projects_root="$runtime_root/projects"
  [[ -d "$projects_root" ]] || die "Required directory not found: $projects_root"

  if [[ -z "${input_path//[[:space:]]/}" ]]; then
    die "Project path cannot be empty."
  fi

  if [[ ! -e "$input_path" ]]; then
    die "Project path does not exist: $input_path"
  fi

  if [[ ! -d "$input_path" ]]; then
    die "Project path is not a directory: $input_path"
  fi

  if ! project_root="$(cd "$input_path" && pwd)"; then
    die "Failed to resolve project path: $input_path"
  fi

  case "$project_root" in
  "$projects_root"/*)
    ;;
  *)
    die "Project path must resolve to asdlc/projects/<project-id>: $project_root"
    ;;
  esac

  relative_from_projects="${project_root#$projects_root/}"
  if [[ -z "$relative_from_projects" || "$relative_from_projects" == */* ]]; then
    die "Project path must resolve to asdlc/projects/<project-id>: $project_root"
  fi

  PROJECT_ROOT="$project_root"
}

validate_project_folder_contract() {
  local definition_path="$1"
  local project_type_code=""

  [[ -f "$definition_path" ]] || die "Project path must point to a project-level folder containing init_progress_definition.yaml: $PROJECT_ROOT"
  project_type_code="$(extract_meta_scalar "$definition_path" "project_type_code" 2>/dev/null || true)"
  if [[ "$project_type_code" == "A" ]]; then
    fail_project_type_a_not_supported
  fi
  collect_usable_repo_paths "$definition_path"
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
    exit 1
  }
}
{
  if (in_meta == 0) {
    next
  }

  line = $0
  if (line !~ /^[[:space:]]{2}[A-Za-z0-9_.-]+:[[:space:]]*/) {
    next
  }

  sub(/^[[:space:]]{2}/, "", line)
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
' "$definition_path"
}

extract_meta_class_repo_path_entries() {
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
function flush_entry() {
  if (current_class != "") {
    print current_class "|" current_state "|" current_path
  }
  current_class = ""
  current_state = ""
  current_path = ""
}
BEGIN {
  in_meta = 0
  in_paths = 0
  current_class = ""
  current_state = ""
  current_path = ""
}
/^meta_info:[[:space:]]*$/ {
  in_meta = 1
  next
}
/^steps:[[:space:]]*$/ {
  if (in_meta == 1) {
    flush_entry()
    exit 0
  }
}
{
  if (in_meta == 0) {
    next
  }

  if (in_paths == 0) {
    if ($0 ~ /^[[:space:]]{2}class_repo_paths:[[:space:]]*\{\}[[:space:]]*$/) {
      exit 0
    }
    if ($0 ~ /^[[:space:]]{2}class_repo_paths:[[:space:]]*$/) {
      in_paths = 1
      next
    }
    next
  }

  if ($0 ~ /^[[:space:]]{2}[A-Za-z0-9_.-]+:[[:space:]]*$/) {
    flush_entry()
    exit 0
  }

  if ($0 ~ /^[[:space:]]{4}[A-Za-z0-9_.-]+:[[:space:]]*$/) {
    flush_entry()
    line = $0
    sub(/^[[:space:]]{4}/, "", line)
    sub(/:[[:space:]]*$/, "", line)
    current_class = trim(line)
    next
  }

  if (current_class != "" && $0 ~ /^[[:space:]]{6}state:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{6}state:[[:space:]]*/, "", line)
    current_state = strip_quotes(line)
    next
  }

  if (current_class != "" && $0 ~ /^[[:space:]]{6}path:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{6}path:[[:space:]]*/, "", line)
    current_path = strip_quotes(line)
    next
  }
}
END {
  flush_entry()
}
' "$definition_path"
}

collect_usable_repo_paths() {
  local definition_path="$1"
  local parsed_entries=""
  local entry=""
  local class_name=""
  local class_state=""
  local class_path=""
  local normalized_state=""
  local normalized_path=""
  local resolved_path=""

  REPO_PATHS=()
  REPO_CONTEXT_LINES=()

  if ! parsed_entries="$(extract_meta_class_repo_path_entries "$definition_path" 2>/dev/null)"; then
    die "Failed to read meta_info.class_repo_paths from $definition_path."
  fi

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    IFS='|' read -r class_name class_state class_path <<<"$entry"

    class_name="$(trim_value "$class_name")"
    normalized_state="$(printf '%s' "$(trim_value "$class_state")" | tr '[:upper:]' '[:lower:]')"
    normalized_path="$(strip_quotes "$class_path")"
    [[ -n "$class_name" ]] || continue

    if [[ "$normalized_state" != "ready" ]]; then
      continue
    fi

    if [[ -z "$normalized_path" ]]; then
      die "Repo path for class '$class_name' is marked ready but path is empty in $definition_path."
    fi

    if [[ ! -d "$normalized_path" ]]; then
      die "Repo path for class '$class_name' does not exist or is not a directory: $normalized_path"
    fi

    if ! resolved_path="$(cd "$normalized_path" && pwd)"; then
      die "Failed to resolve repo path for class '$class_name': $normalized_path"
    fi

    if ! array_contains "$resolved_path" "${REPO_PATHS[@]-}"; then
      REPO_PATHS+=("$resolved_path")
      REPO_CONTEXT_LINES+=("- $class_name: $resolved_path")
    fi
  done <<<"$parsed_entries"

  if [[ ${#REPO_PATHS[@]} -eq 0 ]]; then
    die "No usable repository paths found in meta_info.class_repo_paths (state: ready with existing directories required)."
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

render_repo_context_lines() {
  local line=""
  for line in "${REPO_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

build_prompt() {
  local repo_root="$1"
  local project_id="$2"
  local project_definition_path="$3"
  local target_artifact_path="$4"
  local quality_command=""
  printf -v quality_command "%q %q" "$QUALITY_GATE_HELPER" "$target_artifact_path"

  cat <<EOF2
Create a cross-project common contract definition artifact for this ASDLC project.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for common-contract-definition generation.
- Use $COMMON_CONTRACT_TEMPLATE_FILE as output structure contract.
- Use $COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE as style contract.
- Update only $target_artifact_path.
- Use repository paths from $project_definition_path key \`meta_info.class_repo_paths\` as the only authoritative repositories for this run.
- For each shared contract, reconcile overlaps/mismatches and assign a clear source of truth.
- Keep repository evidence summary concise but concrete.
- Do not duplicate repository-structure or project-tech baseline artifacts.
- Before finishing, ensure the output can pass this quality gate command: $quality_command
- Treat helper failure messages as authoritative fix instructions; after each fix, rerun the helper command until it exits 0.
- Evaluate whether gate compliance is feasible with current repository evidence and constraints.
- If gate compliance is not feasible, stop and end with this exact line:
  "common contract definition gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase"
- If the quality gate is feasible and passed, end your final response with this exact last line:
  "Common contract definition phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Repository root: $repo_root
- ASDLC project root: $PROJECT_ROOT
- Project id: $project_id
- Project definition file: $project_definition_path
- Target common contract definition artifact: $target_artifact_path
- Rule file: $RULE_FILE
- Template file: $COMMON_CONTRACT_TEMPLATE_FILE
- Golden example file: $COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
- Authoritative repository paths to analyze:
$(render_repo_context_lines)
EOF2
}

commit_generated_artifact() {
  local repo_root="$1"
  local project_id="$2"
  local artifact_path="$3"
  local artifact_rel_path=""
  local commit_message="Update common contract definition for $project_id"

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Runtime root is not a git repository: $repo_root"
  fi

  if [[ "$artifact_path" != "$repo_root/"* ]]; then
    die "Generated artifact path must stay inside ASDLC runtime root: $artifact_path"
  fi

  artifact_rel_path="${artifact_path#$repo_root/}"

  if ! git -C "$repo_root" add -- "$artifact_rel_path"; then
    die "Failed to stage generated common contract definition: $artifact_rel_path"
  fi

  if git -C "$repo_root" diff --cached --quiet -- "$artifact_rel_path"; then
    die "No staged changes found for generated common contract definition: $artifact_rel_path"
  fi

  if ! git -C "$repo_root" commit -m "$commit_message" -- "$artifact_rel_path" >/dev/null 2>&1; then
    die "Failed to commit generated common contract definition: $artifact_rel_path"
  fi
}

main() {
  require_command awk
  require_command git
  parse_args "$@"

  local repo_root=""
  local project_definition_path=""
  local models_path=""
  local prompt_arg=""
  local project_id=""
  local target_artifact_path=""

  resolve_runtime_root
  repo_root="$RUNTIME_ROOT"
  resolve_project_root "$PROJECT_PATH_INPUT" "$repo_root"
  project_definition_path="$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  validate_project_folder_contract "$project_definition_path"

  ensure_required_files "$repo_root"

  project_id="$(extract_meta_scalar "$project_definition_path" "project_id" 2>/dev/null || true)"
  if [[ -z "$project_id" ]]; then
    project_id="$(basename "$PROJECT_ROOT")"
  fi

  models_path="$repo_root/$MODELS_FILE"
  target_artifact_path="$PROJECT_ROOT/$PROJECT_OUTPUT_FILE"

  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_prompt "$repo_root" "$project_id" "$project_definition_path" "$target_artifact_path")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$repo_root"
    "${cmd[@]}"
  )

  if [[ ! -f "$target_artifact_path" ]]; then
    die "Model run did not produce required file: $target_artifact_path"
  fi

  commit_generated_artifact "$repo_root" "$project_id" "$target_artifact_path"

  echo "Updated $target_artifact_path"
  echo "Committed $target_artifact_path"
}

main "$@"
