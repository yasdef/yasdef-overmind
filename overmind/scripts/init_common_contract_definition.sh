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
CROSS_CLASS_PEER_TRIGGER_HELPER=".helper/check_cross_class_peer_trigger.sh"
MODEL_PHASE="common_contract_definition"
RUNTIME_ROOT=""

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
REPO_PATHS=()
REPO_CONTEXT_LINES=()
ACTIVE_STACK_CLASSES=()
STACK_BLUEPRINT_PATHS=()
STACK_BLUEPRINT_CONTEXT_LINES=()
STACK_BLUEPRINT_SNAPSHOTS=()

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

  die "initialize the ASDLC workspace first; run this script only from asdlc/.commands"
}

ensure_required_files() {
  local repo_root="$1"
  local required_paths=(
    "$MODELS_FILE"
    "$RULE_FILE"
    "$COMMON_CONTRACT_TEMPLATE_FILE"
    "$COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE"
    "$QUALITY_GATE_HELPER"
    "$CROSS_CLASS_PEER_TRIGGER_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$repo_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

source_class_repo_paths_lib() {
  local runtime_root="$1"
  local lib_path="$runtime_root/common_libs/class_repo_paths.sh"
  [[ -f "$lib_path" ]] || die "Required command lib not found: common_libs/class_repo_paths.sh"
  # shellcheck source=/dev/null
  source "$lib_path"
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
    collect_stack_blueprint_paths "$definition_path"
    validate_stack_blueprints
    return 0
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

  if ! parsed_entries="$(class_repo_paths_extract_entries "$definition_path" 2>/dev/null)"; then
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

extract_project_classes() {
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
    count = split(line, parts, ",")
    for (i = 1; i <= count; i++) {
      value = strip_quotes(parts[i])
      if (value != "") print value
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
      value = strip_quotes(line)
      if (value != "") print value
      next
    }
    in_classes = 0
  }
}
' "$definition_path"
}

collect_stack_blueprint_paths() {
  local definition_path="$1"
  local class_name=""
  local blueprint_path=""

  ACTIVE_STACK_CLASSES=()
  STACK_BLUEPRINT_PATHS=()
  STACK_BLUEPRINT_CONTEXT_LINES=()

  while IFS= read -r class_name; do
    class_name="$(strip_quotes "$class_name")"
    [[ -n "$class_name" ]] || continue
    case "$class_name" in
    backend|frontend|mobile)
      if array_contains "$class_name" "${ACTIVE_STACK_CLASSES[@]-}"; then
        continue
      fi
      blueprint_path="$PROJECT_ROOT/project_stack_blueprint_${class_name}.md"
      ACTIVE_STACK_CLASSES+=("$class_name")
      STACK_BLUEPRINT_PATHS+=("$blueprint_path")
      STACK_BLUEPRINT_CONTEXT_LINES+=("- $class_name: $blueprint_path")
      ;;
    *)
      ;;
    esac
  done < <(extract_project_classes "$definition_path")
}

validate_stack_blueprints() {
  local blueprint_path=""

  if [[ ${#STACK_BLUEPRINT_PATHS[@]} -eq 0 ]]; then
    die "No active backend/frontend/mobile classes found for type A stack blueprint context."
  fi

  for blueprint_path in "${STACK_BLUEPRINT_PATHS[@]}"; do
    [[ -f "$blueprint_path" ]] || die "Required type A stack blueprint is missing before Step 2: $blueprint_path"
  done
}

snapshot_stack_blueprints() {
  local blueprint_path=""
  local snapshot_path=""

  STACK_BLUEPRINT_SNAPSHOTS=()
  for blueprint_path in "${STACK_BLUEPRINT_PATHS[@]}"; do
    if ! snapshot_path="$(mktemp)"; then
      die "Failed to create stack blueprint snapshot."
    fi
    if ! cp "$blueprint_path" "$snapshot_path"; then
      rm -f "$snapshot_path"
      die "Failed to snapshot stack blueprint: $blueprint_path"
    fi
    STACK_BLUEPRINT_SNAPSHOTS+=("$snapshot_path")
  done
}

verify_stack_blueprints_unchanged() {
  local index=0
  local blueprint_path=""
  local snapshot_path=""

  for blueprint_path in "${STACK_BLUEPRINT_PATHS[@]}"; do
    snapshot_path="${STACK_BLUEPRINT_SNAPSHOTS[$index]}"
    if ! cmp -s "$snapshot_path" "$blueprint_path"; then
      die "Step 2 modified read-only stack blueprint: $blueprint_path"
    fi
    index=$((index + 1))
  done
}

cleanup_stack_blueprint_snapshots() {
  local snapshot_path=""
  for snapshot_path in "${STACK_BLUEPRINT_SNAPSHOTS[@]-}"; do
    [[ -n "$snapshot_path" && -f "$snapshot_path" ]] && rm -f "$snapshot_path"
  done
}

commit_initialization_baseline() {
  local project_type_code="$1"
  local blueprint_path=""
  local remaining_changes=""
  local unexpected_changes=""
  local -a baseline_paths=(
    "$PROJECT_DEFINITION_FILE"
    "$PROJECT_OUTPUT_FILE"
  )
  local -a status_pathspecs=(".")

  if [[ "$project_type_code" == "A" ]]; then
    for blueprint_path in "${STACK_BLUEPRINT_PATHS[@]}"; do
      baseline_paths+=("${blueprint_path#"$PROJECT_ROOT/"}")
    done
  fi
  for blueprint_path in "${baseline_paths[@]}"; do
    status_pathspecs+=(":(exclude)$blueprint_path")
  done

  if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Project path must be a git repository to finalize initialization baseline: $PROJECT_ROOT"
  fi
  if ! unexpected_changes="$(git -C "$PROJECT_ROOT" status --porcelain -- "${status_pathspecs[@]}")"; then
    die "Failed to validate project initialization baseline paths."
  fi
  if [[ -n "$unexpected_changes" ]]; then
    echo "ERROR: Project initialization created unexpected changes; baseline was not committed:" >&2
    printf '%s\n' "$unexpected_changes" >&2
    exit 1
  fi

  git -C "$PROJECT_ROOT" add -- "${baseline_paths[@]}" || die "Failed to stage project initialization baseline."
  if ! git -C "$PROJECT_ROOT" diff --cached --quiet -- "${baseline_paths[@]}"; then
    git -C "$PROJECT_ROOT" commit -m "Finalize project initialization baseline" -- "${baseline_paths[@]}" >/dev/null \
      || die "Failed to commit project initialization baseline."
    echo "Committed project initialization baseline."
  fi

  if ! remaining_changes="$(git -C "$PROJECT_ROOT" status --porcelain)"; then
    die "Failed to verify project initialization baseline."
  fi
  if [[ -n "$remaining_changes" ]]; then
    echo "ERROR: Project initialization baseline left unexpected uncommitted changes:" >&2
    printf '%s\n' "$remaining_changes" >&2
    exit 1
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

render_stack_blueprint_context_lines() {
  local line=""
  for line in "${STACK_BLUEPRINT_CONTEXT_LINES[@]}"; do
    printf '%s\n' "$line"
  done
}

build_prompt() {
  local repo_root="$1"
  local project_id="$2"
  local project_definition_path="$3"
  local target_artifact_path="$4"
  local project_type_code="$5"
  local quality_command=""
  printf -v quality_command "%q %q" "$QUALITY_GATE_HELPER" "$target_artifact_path"

  local source_context=""
  if [[ "$project_type_code" == "A" ]]; then
    source_context=$(cat <<EOF_A
- Project type A stack-family blueprints are read-only project context only:
$(render_stack_blueprint_context_lines)
- Use the approved stack-family choices only as high-level project context.
- Do not treat stack blueprints as API contract schemas, shared request/response definitions, repository scan evidence, or Step 7 surface-map evidence.
- Do not modify stack blueprint files.
EOF_A
)
  else
    source_context=$(cat <<EOF_BC
- Use repository paths from $project_definition_path key \`meta_info.class_repo_paths\` as the only authoritative repositories for this run.
- Authoritative repository paths to analyze:
$(render_repo_context_lines)
EOF_BC
)
  fi

  cat <<EOF2
Create a cross-project common contract definition artifact for this ASDLC project.

Hard constraints:
- Read and follow $RULE_FILE fully before editing.
- Treat $RULE_FILE as authoritative for common-contract-definition generation.
- Use $COMMON_CONTRACT_TEMPLATE_FILE as output structure contract.
- Use $COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE as style contract.
- Update only $target_artifact_path.
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
- Project type code: $project_type_code
- Project definition file: $project_definition_path
- Target common contract definition artifact: $target_artifact_path
- Rule file: $RULE_FILE
- Template file: $COMMON_CONTRACT_TEMPLATE_FILE
- Golden example file: $COMMON_CONTRACT_GOLDEN_EXAMPLE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Quality gate command: $quality_command
- Cross-class peer trigger helper command: $CROSS_CLASS_PEER_TRIGGER_HELPER $project_definition_path
$source_context
EOF2
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command git
  require_command mktemp
  parse_args "$@"

  local repo_root=""
  local project_definition_path=""
  local models_path=""
  local prompt_arg=""
  local project_id=""
  local target_artifact_path=""
  local project_type_code=""

  resolve_runtime_root
  repo_root="$RUNTIME_ROOT"
  source_class_repo_paths_lib "$repo_root"
  resolve_project_root "$PROJECT_PATH_INPUT" "$repo_root"
  project_definition_path="$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  validate_project_folder_contract "$project_definition_path"
  project_type_code="$(extract_meta_scalar "$project_definition_path" "project_type_code" 2>/dev/null || true)"

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

  if [[ "$project_type_code" == "A" ]]; then
    snapshot_stack_blueprints
    trap cleanup_stack_blueprint_snapshots EXIT
  fi

  prompt_arg="$(build_prompt "$repo_root" "$project_id" "$project_definition_path" "$target_artifact_path" "$project_type_code")"

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

  if [[ "$project_type_code" == "A" ]]; then
    verify_stack_blueprints_unchanged
    cleanup_stack_blueprint_snapshots
    trap - EXIT
  fi

  commit_initialization_baseline "$project_type_code"
  echo "Updated $target_artifact_path"
}

main "$@"
