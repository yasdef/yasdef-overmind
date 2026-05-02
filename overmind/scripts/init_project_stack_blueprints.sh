#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH_INPUT=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
MODELS_FILE=".setup/models.md"
BLUEPRINT_RULE_FILE=".rules/project_stack_blueprint_rule.md"
QUALITY_GATE_HELPER=".helper/check_project_stack_blueprint_quality.sh"
CROSS_CLASS_PEER_TRIGGER_HELPER=".helper/check_cross_class_peer_trigger.sh"
EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"
MODEL_PHASE="project_stack_blueprint"
RUNTIME_ROOT=""

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()
ACTIVE_STACK_CLASSES=()
TARGET_BLUEPRINT_PATHS=()

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
  local value=""
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

ensure_required_files() {
  local repo_root="$1"
  local required_paths=(
    "$MODELS_FILE"
    "$BLUEPRINT_RULE_FILE"
    "$QUALITY_GATE_HELPER"
    "$CROSS_CLASS_PEER_TRIGGER_HELPER"
    "$EXTERNAL_SOURCES_FILE"
    ".templates/project_stack_blueprint_be_TEMPLATE.md"
    ".templates/project_stack_blueprint_fe_TEMPLATE.md"
    ".templates/project_stack_blueprint_mobile_TEMPLATE.md"
    ".golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
    ".golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
    ".golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$repo_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
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

template_for_class() {
  case "$1" in
  backend) printf '%s' ".templates/project_stack_blueprint_be_TEMPLATE.md" ;;
  frontend) printf '%s' ".templates/project_stack_blueprint_fe_TEMPLATE.md" ;;
  mobile) printf '%s' ".templates/project_stack_blueprint_mobile_TEMPLATE.md" ;;
  *) return 1 ;;
  esac
}

golden_for_class() {
  case "$1" in
  backend) printf '%s' ".golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md" ;;
  frontend) printf '%s' ".golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md" ;;
  mobile) printf '%s' ".golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md" ;;
  *) return 1 ;;
  esac
}

target_for_class() {
  printf '%s/project_stack_blueprint_%s.md' "$PROJECT_ROOT" "$1"
}

load_active_stack_classes() {
  local definition_path="$1"
  local class_name=""
  local target_path=""

  ACTIVE_STACK_CLASSES=()
  TARGET_BLUEPRINT_PATHS=()

  while IFS= read -r class_name; do
    class_name="$(strip_quotes "$class_name")"
    [[ -n "$class_name" ]] || continue
    case "$class_name" in
    backend|frontend|mobile)
      if ! array_contains "$class_name" "${ACTIVE_STACK_CLASSES[@]-}"; then
        ACTIVE_STACK_CLASSES+=("$class_name")
        target_path="$(target_for_class "$class_name")"
        TARGET_BLUEPRINT_PATHS+=("$target_path")
      fi
      ;;
    *)
      ;;
    esac
  done < <(extract_project_classes "$definition_path")
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

render_class_context() {
  local index=0
  local class_name=""
  local target_path=""
  local template_path=""
  local golden_path=""

  for class_name in "${ACTIVE_STACK_CLASSES[@]}"; do
    target_path="${TARGET_BLUEPRINT_PATHS[$index]}"
    template_path="$(template_for_class "$class_name")"
    golden_path="$(golden_for_class "$class_name")"
    cat <<EOF2
- Class: $class_name
  - Target artifact: $target_path
  - Template: $template_path
  - Golden example: $golden_path
  - Quality gate command: $QUALITY_GATE_HELPER $target_path
EOF2
    index=$((index + 1))
  done
}

build_prompt() {
  local repo_root="$1"
  local project_definition_path="$2"
  local external_sources_status=""

  if [[ -f "$repo_root/$EXTERNAL_SOURCES_FILE" ]]; then
    external_sources_status="present"
  else
    external_sources_status="absent — use bounded fallback proposals for all classes"
  fi

  cat <<EOF2
Run Step 1.1: approve project stack blueprints for this type A ASDLC project.

- Read $BLUEPRINT_RULE_FILE fully before proceeding; it is authoritative for all authoring flow behavior and final artifact content.
- Process each active class independently.
- Do not write a final project_stack_blueprint_<class>.md file until the user explicitly approves that class's final blueprint, including stack choices, planned repo identity, and layer bindings.
- After writing each final blueprint, run its quality gate command; gate behavior rules are in $BLUEPRINT_RULE_FILE.
- When all required blueprints are approved and pass their quality gates, end your final response with this exact last line:
  "Project stack blueprint phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"

Context:
- Repository root: $repo_root
- ASDLC project root: $PROJECT_ROOT
- Project definition file: $project_definition_path
- Blueprint rule file: $BLUEPRINT_RULE_FILE
- Quality gate helper: $QUALITY_GATE_HELPER
- Cross-class peer trigger helper command: $CROSS_CLASS_PEER_TRIGGER_HELPER $project_definition_path
- External sources config: $EXTERNAL_SOURCES_FILE ($external_sources_status)
- Active class outputs:
$(render_class_context)
EOF2
}

commit_generated_artifacts() {
  local repo_root="$1"
  local project_id="$2"
  local rel_paths=()
  local path=""
  local rel_path=""

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Runtime root is not a git repository: $repo_root"
  fi

  for path in "${TARGET_BLUEPRINT_PATHS[@]}"; do
    if [[ "$path" != "$repo_root/"* ]]; then
      die "Generated artifact path must stay inside ASDLC runtime root: $path"
    fi
    rel_path="${path#$repo_root/}"
    rel_paths+=("$rel_path")
  done

  if ! git -C "$repo_root" add -- "${rel_paths[@]}"; then
    die "Failed to stage generated stack blueprints."
  fi

  if git -C "$repo_root" diff --cached --quiet -- "${rel_paths[@]}"; then
    echo "No stack blueprint changes to commit."
    return 0
  fi

  if ! git -C "$repo_root" commit -m "Update project stack blueprints for $project_id" -- "${rel_paths[@]}" >/dev/null 2>&1; then
    die "Failed to commit generated stack blueprints."
  fi
}

main() {
  require_command awk
  require_command git
  parse_args "$@"

  local repo_root=""
  local project_definition_path=""
  local project_type_code=""
  local project_id=""
  local prompt_arg=""
  local models_path=""

  resolve_runtime_root
  repo_root="$RUNTIME_ROOT"
  resolve_project_root "$PROJECT_PATH_INPUT" "$repo_root"
  project_definition_path="$PROJECT_ROOT/$PROJECT_DEFINITION_FILE"
  [[ -f "$project_definition_path" ]] || die "Project path must point to a project-level folder containing init_progress_definition.yaml: $PROJECT_ROOT"

  project_type_code="$(extract_meta_scalar "$project_definition_path" "project_type_code" 2>/dev/null || true)"
  if [[ "$project_type_code" != "A" ]]; then
    echo "Project type $project_type_code does not require stack blueprints; Step 1.1 no-op."
    exit 0
  fi

  ensure_required_files "$repo_root"
  load_active_stack_classes "$project_definition_path"
  if [[ ${#ACTIVE_STACK_CLASSES[@]} -eq 0 ]]; then
    echo "No backend/frontend/mobile classes are active; Step 1.1 no-op."
    exit 0
  fi

  project_id="$(extract_meta_scalar "$project_definition_path" "project_id" 2>/dev/null || true)"
  if [[ -z "$project_id" ]]; then
    project_id="$(basename "$PROJECT_ROOT")"
  fi

  models_path="$repo_root/$MODELS_FILE"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  prompt_arg="$(build_prompt "$repo_root" "$project_definition_path")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$repo_root"
    "${cmd[@]}"
  )

  commit_generated_artifacts "$repo_root" "$project_id"

  echo "Updated project stack blueprints for $PROJECT_ROOT"
}

main "$@"
