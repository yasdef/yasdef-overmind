#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"
TARGET_PATH_INPUT=""
TARGET_PROJECT_PATH=""
PROJECT_ROOT=""
FEATURE_PATH=""
OUTPUT_FILE=""
DEFINITION_FILE=""
FEATURE_ID=""
FEATURE_TITLE=""
PROJECT_TYPE_CODE=""
PROJECT_TYPE_LABEL=""

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

normalize_input_path() {
  local raw_path="${1:-}"
  local normalized="$raw_path"

  normalized="${normalized#./}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done

  if [[ -z "$normalized" ]]; then
    die "path must not be empty."
  fi

  printf '%s' "$normalized"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --path."
      TARGET_PATH_INPUT="$(normalize_input_path "$1")"
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$TARGET_PATH_INPUT" ]] || die "Missing required argument: --path <project-folder-path>."
}

resolve_runtime_root() {
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

resolve_target_project_path() {
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
    die "Project path directory not found: $input_path"
  fi

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    die "Failed to resolve project path: $input_path"
  fi

  case "$resolved_path" in
  "$runtime_root"/*)
    ;;
  *)
    die "Path must resolve inside ASDLC workspace: $resolved_path"
    ;;
  esac

  TARGET_PROJECT_PATH="${resolved_path#"$runtime_root/"}"
}

resolve_definition_file_from_ancestor() {
  local runtime_root="$1"
  local search_relative_path="$2"
  local search_dir="$runtime_root/$search_relative_path"
  local candidate=""
  local project_root_relative=""

  while true; do
    candidate="$search_dir/init_progress_definition.yaml"
    if [[ -f "$candidate" ]]; then
      DEFINITION_FILE="${candidate#"$runtime_root/"}"
      project_root_relative="${search_dir#"$runtime_root/"}"
      if [[ -z "$project_root_relative" || "$project_root_relative" == "$search_dir" ]]; then
        die "Project path must resolve to a project-level folder containing init_progress_definition.yaml: $search_relative_path"
      fi
      PROJECT_ROOT="$project_root_relative"
      return 0
    fi

    if [[ "$search_dir" == "$runtime_root" ]]; then
      break
    fi

    search_dir="$(dirname "$search_dir")"
    case "$search_dir" in
    "$runtime_root"|"$runtime_root"/*)
      ;;
    *)
      break
      ;;
    esac
  done

  die "Required file not found: <path ancestor>/init_progress_definition.yaml (path: $TARGET_PROJECT_PATH)"
}

project_type_label_for_code() {
  case "$1" in
  A)
    printf '%s' "New project"
    ;;
  B)
    printf '%s' "Existing project with partial context"
    ;;
  C)
    printf '%s' "Existing project with code-first context"
    ;;
  *)
    return 1
    ;;
  esac
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
/^[^[:space:]][^:]*:[[:space:]]*$/ {
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

load_repo_metadata() {
  local definition_path="$1"
  local expected_label=""

  if ! PROJECT_TYPE_CODE="$(extract_meta_scalar "$definition_path" "project_type_code" 2>/dev/null)"; then
    return 1
  fi
  if ! PROJECT_TYPE_LABEL="$(extract_meta_scalar "$definition_path" "project_type_label" 2>/dev/null)"; then
    return 1
  fi
  if ! expected_label="$(project_type_label_for_code "$PROJECT_TYPE_CODE" 2>/dev/null)"; then
    return 1
  fi
  [[ "$PROJECT_TYPE_LABEL" == "$expected_label" ]]
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

prompt_required_input() {
  local prompt="$1"
  local value=""

  while true; do
    printf '%s ' "$prompt" >&2
    if ! IFS= read -r value; then
      die "User input aborted."
    fi
    value="$(trim_value "$value")"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    echo "Input cannot be empty." >&2
  done
}

prompt_feature_inputs() {
  FEATURE_ID="$(prompt_required_input "Feature ID:")"
  FEATURE_TITLE="$(prompt_required_input "Feature title:")"
}

normalize_feature_folder_name() {
  local raw_name="$1"

  printf '%s' "$raw_name" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g'
}

set_output_paths() {
  local normalized_feature_name=""
  local feature_timestamp=""

  normalized_feature_name="$(normalize_feature_folder_name "$FEATURE_TITLE")"
  if [[ -z "$normalized_feature_name" ]]; then
    die "Feature title must contain at least one letter or digit."
  fi

  feature_timestamp="$(date +%s)"
  if [[ ! "$feature_timestamp" =~ ^[0-9]+$ ]]; then
    die "Failed to generate unix timestamp for feature folder name."
  fi

  FEATURE_PATH="$PROJECT_ROOT/${normalized_feature_name}-${feature_timestamp}"
  OUTPUT_FILE="$FEATURE_PATH/feature_br_summary.md"
}

ensure_output_target_available() {
  local runtime_root="$1"

  if [[ -e "$runtime_root/$FEATURE_PATH" ]]; then
    die "Target feature folder already exists: $FEATURE_PATH"
  fi
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$TEMPLATE_FILE"
    "$DEFINITION_FILE"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

write_feature_br_summary() {
  local runtime_root="$1"
  local output_path="$runtime_root/$OUTPUT_FILE"
  local template_path="$runtime_root/$TEMPLATE_FILE"
  local tmp_output=""
  local escaped_feature_id=""
  local escaped_feature_title=""
  local escaped_code=""
  local escaped_label=""

  [[ -f "$template_path" ]] || die "Template file not found: $TEMPLATE_FILE"

  mkdir -p "$(dirname "$output_path")"
  tmp_output="$(mktemp)"

  escaped_feature_id="$(escape_sed_replacement "$FEATURE_ID")"
  escaped_feature_title="$(escape_sed_replacement "$FEATURE_TITLE")"
  escaped_code="$(escape_sed_replacement "$PROJECT_TYPE_CODE")"
  escaped_label="$(escape_sed_replacement "$PROJECT_TYPE_LABEL")"

  sed \
    -e "s/- feature_id: \[UNFILLED\]/- feature_id: $escaped_feature_id/g" \
    -e "s/- feature_title: \[UNFILLED\]/- feature_title: $escaped_feature_title/g" \
    -e "s/{{PROJECT_TYPE_CODE}}/$escaped_code/g" \
    -e "s/{{PROJECT_TYPE_LABEL}}/$escaped_label/g" \
    -e "s/- ready_to_ears: \[UNFILLED\]/- ready_to_ears: false/g" \
    "$template_path" >"$tmp_output"

  mv "$tmp_output" "$output_path"
  rm -f "$tmp_output"

  echo "Created feature folder: $FEATURE_PATH"
  echo "Updated $OUTPUT_FILE"
}

commit_feature_br_summary_if_changed() {
  local runtime_root="$1"

  if ! git -C "$runtime_root" add "$OUTPUT_FILE"; then
    die "Failed to stage $OUTPUT_FILE."
  fi

  if git -C "$runtime_root" diff --cached --quiet -- "$OUTPUT_FILE"; then
    return 0
  fi

  if ! git -C "$runtime_root" commit -m "Initialize feature BR scaffold" -- "$OUTPUT_FILE" >/dev/null 2>&1; then
    die "Failed to commit $OUTPUT_FILE."
  fi
}

main() {
  require_command git
  require_command awk
  require_command sed
  require_command tr
  require_command date
  parse_args "$@"

  local runtime_root=""
  runtime_root="$(resolve_runtime_root)"

  resolve_target_project_path "$runtime_root" "$TARGET_PATH_INPUT"
  resolve_definition_file_from_ancestor "$runtime_root" "$TARGET_PROJECT_PATH"
  ensure_required_files "$runtime_root"

  if ! load_repo_metadata "$runtime_root/$DEFINITION_FILE"; then
    die "Unable to load project metadata for BR scaffold init."
  fi

  prompt_feature_inputs
  set_output_paths
  ensure_output_target_available "$runtime_root"
  write_feature_br_summary "$runtime_root"
  commit_feature_br_summary_if_changed "$runtime_root"
}

main "$@"
