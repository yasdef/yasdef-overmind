#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
PROJECT_DEFINITION_FILE=""

EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"
MODELS_FILE=".setup/models.md"
RULE_FILE=".rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"
BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
MODEL_PHASE="feature_surface_map_mcp_placeholder_enrichment"

PLACEHOLDER_LITERAL="<to be defined during implementation>"

MODEL_CMD=""
MODEL_MODEL=""
MODEL_ARGS=()

MAPS_WITH_PLACEHOLDERS=()
MAPS_WITH_PLACEHOLDER_CLASSES=()
ELIGIBLE_SOURCE_NAMES=()

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
    "$runtime_root"/*) ;;
    *) die "Feature path must resolve inside ASDLC workspace: $resolved_path" ;;
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
  PROJECT_DEFINITION_FILE="$PROJECT_ROOT/init_progress_definition.yaml"
}

class_for_surface_map_file() {
  local filename="$1"
  case "$filename" in
    *backend*) printf '%s' "backend" ;;
    *frontend*) printf '%s' "frontend" ;;
    *mobile*) printf '%s' "mobile" ;;
    *) printf '%s' "unknown" ;;
  esac
}

collect_maps_with_placeholders() {
  local runtime_root="$1"
  local surface_map_path=""
  local class_name=""

  MAPS_WITH_PLACEHOLDERS=()
  MAPS_WITH_PLACEHOLDER_CLASSES=()

  for class_name in backend frontend mobile; do
    surface_map_path="$FEATURE_PATH/project_surface_struct_resp_map_${class_name}.md"
    if [[ ! -f "$runtime_root/$surface_map_path" ]]; then
      continue
    fi
    if grep -qF "$PLACEHOLDER_LITERAL" "$runtime_root/$surface_map_path" 2>/dev/null; then
      MAPS_WITH_PLACEHOLDERS+=("$surface_map_path")
      MAPS_WITH_PLACEHOLDER_CLASSES+=("$class_name")
    fi
  done
}

is_knowledge_base_name() {
  local name="$1"
  local name_lower
  name_lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  case "$name_lower" in
    *knowledge*|*kb*) return 0 ;;
    *) return 1 ;;
  esac
}

collect_eligible_kb_sources() {
  local sources_path="$1"
  local raw_names=""
  local name=""

  ELIGIBLE_SOURCE_NAMES=()

  if [[ ! -f "$sources_path" ]]; then
    return 0
  fi

  raw_names="$(
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
BEGIN { in_sources = 0 }
/^sources:[[:space:]]*\[\][[:space:]]*$/ { exit 0 }
/^sources:[[:space:]]*$/ { in_sources = 1; next }
in_sources == 1 {
  if ($0 ~ /^[^[:space:]#]/) { in_sources = 0; next }
  if ($0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", line)
    name = strip_quotes(line)
    if (name != "") print name
  }
}
' "$sources_path"
  )"

  while IFS= read -r name; do
    name="$(trim_value "$name")"
    [[ -n "$name" ]] || continue
    if is_knowledge_base_name "$name"; then
      ELIGIBLE_SOURCE_NAMES+=("$name")
    fi
  done <<<"$raw_names"
}

ensure_external_sources_file() {
  local runtime_root="$1"

  if [[ ! -f "$runtime_root/$EXTERNAL_SOURCES_FILE" ]]; then
    die "Required file not found: $EXTERNAL_SOURCES_FILE"
  fi
}

ensure_model_runtime_files() {
  local runtime_root="$1"
  local required_paths=(
    "$MODELS_FILE"
    "$RULE_FILE"
    "$BACKEND_QUALITY_GATE_HELPER"
    "$FRONTEND_MOBILE_QUALITY_GATE_HELPER"
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

build_surface_map_list() {
  local idx=0
  local map_file=""
  local class_name=""
  local quality_helper=""
  local result=""

  for idx in "${!MAPS_WITH_PLACEHOLDERS[@]}"; do
    map_file="${MAPS_WITH_PLACEHOLDERS[$idx]}"
    class_name="${MAPS_WITH_PLACEHOLDER_CLASSES[$idx]}"
    case "$class_name" in
      backend) quality_helper="$BACKEND_QUALITY_GATE_HELPER" ;;
      *) quality_helper="$FRONTEND_MOBILE_QUALITY_GATE_HELPER" ;;
    esac
    result="${result}
  - file: $map_file
    class: $class_name
    quality_gate: $quality_helper $map_file"
  done

  printf '%s' "$result"
}

build_source_names_list() {
  local name=""
  local result=""

  for name in "${ELIGIBLE_SOURCE_NAMES[@]}"; do
    result="${result}
  - $name"
  done

  printf '%s' "$result"
}

build_prompt() {
  local runtime_root="$1"
  local surface_map_list="$2"
  local source_names_list="$3"

  cat <<EOF
Enrich surface-map placeholder fields using a configured knowledge-base MCP source.

Hard constraints:
- Read and follow $RULE_FILE fully before making any edits.
- Treat $RULE_FILE as authoritative for this phase.
- Read these as input only and do not modify them:
  - $EXTERNAL_SOURCES_FILE
  - $RULE_FILE
  - $MODELS_FILE
- Update only the surface-map files listed in Context below (in-place placeholder replacements only).
- Backend surface map quality gate command: $BACKEND_QUALITY_GATE_HELPER <map_file>
- Frontend/mobile surface map quality gate command: $FRONTEND_MOBILE_QUALITY_GATE_HELPER <map_file>

Context:
- ASDLC workspace root: $runtime_root
- Feature root: $FEATURE_PATH
- Rule file: $RULE_FILE
- External sources config: $EXTERNAL_SOURCES_FILE
- Backend quality gate helper: $BACKEND_QUALITY_GATE_HELPER
- Frontend/mobile quality gate helper: $FRONTEND_MOBILE_QUALITY_GATE_HELPER
- Surface maps with placeholders:$surface_map_list
- Eligible knowledge-base MCP source names:$source_names_list
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

commit_changed_maps_if_needed() {
  local runtime_root="$1"
  shift
  local changed_maps=("$@")

  if [[ ${#changed_maps[@]} -eq 0 ]]; then
    return 0
  fi

  if ! git -C "$runtime_root" add -- "${changed_maps[@]}"; then
    die "Failed to stage enriched surface-map artifacts."
  fi

  if git -C "$runtime_root" diff --cached --quiet -- "${changed_maps[@]}"; then
    return 0
  fi

  if ! git -C "$runtime_root" commit -m "Enrich surface-map placeholders with MCP" -- "${changed_maps[@]}" >/dev/null 2>&1; then
    die "Failed to commit enriched surface-map artifacts."
  fi
}

main() {
  require_command git
  require_command awk
  require_command cmp
  require_command cp
  require_command mktemp
  require_command grep
  parse_args "$@"

  local runtime_root=""
  local sources_path=""
  local models_path=""
  local prompt_arg=""
  local before_sources=""
  local before_definition=""
  local surface_map_list=""
  local source_names_list=""

  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root

  collect_maps_with_placeholders "$runtime_root"

  if [[ ${#MAPS_WITH_PLACEHOLDERS[@]} -eq 0 ]]; then
    echo "Step 7.1: No surface maps with placeholders found. Nothing to enrich."
    exit 0
  fi

  sources_path="$runtime_root/$EXTERNAL_SOURCES_FILE"
  ensure_external_sources_file "$runtime_root"
  collect_eligible_kb_sources "$sources_path"

  if [[ ${#ELIGIBLE_SOURCE_NAMES[@]} -eq 0 ]]; then
    echo "Step 7.1: No eligible knowledge-base sources configured. Nothing to enrich."
    exit 0
  fi

  ensure_model_runtime_files "$runtime_root"
  models_path="$runtime_root/$MODELS_FILE"
  load_model_config "$models_path" "$MODEL_PHASE"
  if [[ "$MODEL_CMD" != "codex" ]]; then
    die "Invalid '$MODEL_PHASE' command in $MODELS_FILE: expected 'codex', got '$MODEL_CMD'."
  fi
  require_command "$MODEL_CMD"

  before_sources="$(mktemp)"
  before_definition="$(mktemp)"
  local maps_snapshot_dir
  maps_snapshot_dir="$(mktemp -d)"
  cp "$sources_path" "$before_sources"
  if [[ -f "$runtime_root/$PROJECT_DEFINITION_FILE" ]]; then
    cp "$runtime_root/$PROJECT_DEFINITION_FILE" "$before_definition"
  fi
  local idx
  for idx in "${!MAPS_WITH_PLACEHOLDERS[@]}"; do
    cp "$runtime_root/${MAPS_WITH_PLACEHOLDERS[$idx]}" "$maps_snapshot_dir/$idx"
  done
  trap '[[ -n "${before_sources:-}" ]] && rm -f "$before_sources"; [[ -n "${before_definition:-}" ]] && rm -f "$before_definition"; [[ -n "${maps_snapshot_dir:-}" ]] && rm -rf "$maps_snapshot_dir"' EXIT

  surface_map_list="$(build_surface_map_list)"
  source_names_list="$(build_source_names_list)"
  prompt_arg="$(build_prompt "$runtime_root" "$surface_map_list" "$source_names_list")"

  local cmd=("$MODEL_CMD" -m "$MODEL_MODEL")
  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi
  cmd+=("$prompt_arg")

  (
    cd "$runtime_root"
    "${cmd[@]}"
  )

  local changed_maps=()
  for idx in "${!MAPS_WITH_PLACEHOLDERS[@]}"; do
    local map_path="$runtime_root/${MAPS_WITH_PLACEHOLDERS[$idx]}"
    if ! cmp -s "$maps_snapshot_dir/$idx" "$map_path"; then
      local tmp_flagged
      tmp_flagged="$(mktemp)"
      sed 's/was_enriched_with_mcp: false/was_enriched_with_mcp: true/' "$map_path" >"$tmp_flagged"
      mv "$tmp_flagged" "$map_path"
      changed_maps+=("${MAPS_WITH_PLACEHOLDERS[$idx]}")
    fi
  done

  ensure_file_unchanged "$before_sources" "$sources_path" "$EXTERNAL_SOURCES_FILE"
  if [[ -f "$runtime_root/$PROJECT_DEFINITION_FILE" ]]; then
    ensure_file_unchanged "$before_definition" "$runtime_root/$PROJECT_DEFINITION_FILE" "$PROJECT_DEFINITION_FILE"
  fi

  if [[ ${#changed_maps[@]} -gt 0 ]]; then
    commit_changed_maps_if_needed "$runtime_root" "${changed_maps[@]}"
    for idx in "${!changed_maps[@]}"; do
      echo "Updated ${changed_maps[$idx]}"
    done
  fi
  echo "Step 7.1: MCP placeholder enrichment complete."
}

main "$@"
