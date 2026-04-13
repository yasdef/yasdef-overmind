#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
PROJECT_PATH_INPUT=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
WORKERS_FILE_NAME="workers.yaml"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

print_usage() {
  cat <<'USAGE'
Usage: project_register_worker.sh --path <asdlc/projects/<project-id>>
USAGE
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

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --path."
      PROJECT_PATH_INPUT="$(trim_value "$1")"
      ;;
    --help | -h)
      print_usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [[ -n "$PROJECT_PATH_INPUT" ]] || die "Missing required argument: --path <asdlc/projects/<project-id>>."
}

resolve_projects_root() {
  local script_dir=""
  local parent_dir=""
  local projects_root=""

  if [[ -n "${ASDLC_PROJECTS_DIR:-}" ]]; then
    if ! projects_root="$(cd "$ASDLC_PROJECTS_DIR" && pwd)"; then
      die "Failed to resolve ASDLC projects directory from ASDLC_PROJECTS_DIR: $ASDLC_PROJECTS_DIR"
    fi
    printf '%s' "$projects_root"
    return 0
  fi

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    die "Failed to resolve script directory."
  fi
  parent_dir="$(dirname "$script_dir")"

  if [[ "$(basename "$script_dir")" == ".commands" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    projects_root="$parent_dir/projects"
    if [[ ! -d "$projects_root" ]]; then
      die "Required directory not found: $projects_root"
    fi
    printf '%s' "$projects_root"
    return 0
  fi

  die "ASDLC projects directory is not configured. Run from staged <asdlc>/.commands/$SCRIPT_BASENAME or set ASDLC_PROJECTS_DIR."
}

resolve_project_root() {
  local input_path="$1"
  local projects_root="$2"
  local workspace_root=""
  local candidate_path=""
  local project_root=""
  local relative_from_projects=""

  workspace_root="$(dirname "$projects_root")"
  candidate_path="$input_path"
  if [[ "$candidate_path" != /* && ! -e "$candidate_path" && -e "$workspace_root/$candidate_path" ]]; then
    candidate_path="$workspace_root/$candidate_path"
  fi

  if [[ ! -e "$candidate_path" ]]; then
    die "Project path does not exist: $input_path"
  fi
  if [[ ! -d "$candidate_path" ]]; then
    die "Project path is not a directory: $input_path"
  fi
  if ! project_root="$(cd "$candidate_path" && pwd)"; then
    die "Failed to resolve project path: $input_path"
  fi

  case "$project_root" in
  "$projects_root"/*)
    ;;
  *)
    die "Project path must resolve to asdlc/projects/<project-id>: $project_root"
    ;;
  esac

  relative_from_projects="${project_root#"$projects_root/"}"
  if [[ -z "$relative_from_projects" || "$relative_from_projects" == */* ]]; then
    die "Project path must resolve to asdlc/projects/<project-id>: $project_root"
  fi

  printf '%s' "$project_root"
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
    exit(found ? 0 : 1)
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

extract_top_level_scalar() {
  local file_path="$1"
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
  found = 0
}
{
  if ($0 ~ /^[[:space:]]*$/) {
    next
  }

  if ($0 !~ /^[A-Za-z0-9_.-]+:[[:space:]]*/) {
    next
  }

  line = $0
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
' "$file_path"
}

escape_yaml_double_quoted_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

ensure_workers_file_shape() {
  local workers_path="$1"

  if grep -Eq '^workers:[[:space:]]*$' "$workers_path"; then
    return 0
  fi

  if grep -Eq '^workers:[[:space:]]*\[[[:space:]]*\][[:space:]]*$' "$workers_path"; then
    local tmp_file=""
    if ! tmp_file="$(mktemp)"; then
      die "Failed to create temporary file while normalizing workers collection."
    fi
    if ! awk '
BEGIN {
  replaced = 0
}
{
  if (replaced == 0 && $0 ~ /^workers:[[:space:]]*\[[[:space:]]*\][[:space:]]*$/) {
    print "workers:"
    replaced = 1
    next
  }
  print $0
}
' "$workers_path" >"$tmp_file"; then
      rm -f "$tmp_file"
      die "Failed to normalize workers collection in: $workers_path"
    fi
    if ! mv "$tmp_file" "$workers_path"; then
      rm -f "$tmp_file"
      die "Failed to write workers registry: $workers_path"
    fi
    return 0
  fi

  die "workers registry must contain top-level 'workers:' collection: $workers_path"
}

normalize_worker_class_selection() {
  local selection="$1"
  local normalized=""

  normalized="$(to_lower "$(trim_value "$selection")")"
  case "$normalized" in
  1 | backend)
    printf 'backend'
    ;;
  2 | frontend)
    printf 'frontend'
    ;;
  3 | mobile)
    printf 'mobile'
    ;;
  4 | infrastructure)
    printf 'infrastructure'
    ;;
  *)
    return 1
    ;;
  esac
}

prompt_worker_class() {
  local selection=""
  local normalized=""

  while true; do
    echo "Select worker class (mandatory):" >&2
    echo "1. backend" >&2
    echo "2. frontend" >&2
    echo "3. mobile" >&2
    echo "4. infrastructure" >&2
    if ! read -r selection; then
      die "Failed to read worker class selection."
    fi

    if normalized="$(normalize_worker_class_selection "$selection")"; then
      printf '%s' "$normalized"
      return 0
    fi

    echo "Invalid selection. Enter 1, 2, 3, or 4 (backend/frontend/mobile/infrastructure)." >&2
  done
}

generate_worker_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
    return 0
  fi

  local hex=""
  hex="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  printf '%s-%s-%s-%s-%s' \
    "${hex:0:8}" "${hex:8:4}" "${hex:12:4}" "${hex:16:4}" "${hex:20:12}"
}

is_valid_uuid() {
  local value="$1"
  [[ "$value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

is_uuid_present_in_workers_file() {
  local workers_path="$1"
  local worker_uuid="$2"
  local escaped_worker_uuid=""
  escaped_worker_uuid="$(printf '%s' "$worker_uuid" | sed 's/[][\\/.*^$]/\\&/g')"
  grep -Eq "^[[:space:]]*uuid:[[:space:]]*\"?${escaped_worker_uuid}\"?[[:space:]]*$" "$workers_path"
}

generate_unique_worker_uuid() {
  local workers_path="$1"
  local worker_uuid=""
  local attempt=""

  for attempt in {1..25}; do
    worker_uuid="$(generate_worker_uuid)"
    if ! is_valid_uuid "$worker_uuid"; then
      continue
    fi
    if ! is_uuid_present_in_workers_file "$workers_path" "$worker_uuid"; then
      printf '%s' "$worker_uuid"
      return 0
    fi
  done

  die "Failed to generate unique worker UUID for workers registry: $workers_path"
}

append_worker_entry() {
  local workers_path="$1"
  local worker_uuid="$2"
  local worker_class="$3"
  local registered_at="$4"

  if [[ -s "$workers_path" ]] && [[ "$(tail -c 1 "$workers_path" 2>/dev/null || true)" != $'\n' ]]; then
    printf '\n' >>"$workers_path"
  fi

  cat >>"$workers_path" <<EOF
  - uuid: "$worker_uuid"
    class: "$worker_class"
    status: "active"
    registered_at: "$registered_at"
EOF
}

main() {
  require_command awk
  require_command date
  require_command grep
  require_command mktemp
  require_command tr

  parse_args "$@"

  local projects_root=""
  local project_root=""
  local project_definition_path=""
  local project_id=""
  local workers_path=""
  local workers_project_id=""
  local selected_worker_class=""
  local worker_uuid=""
  local registered_at=""

  projects_root="$(resolve_projects_root)"
  project_root="$(resolve_project_root "$PROJECT_PATH_INPUT" "$projects_root")"
  project_definition_path="$project_root/$PROJECT_DEFINITION_FILE"
  workers_path="$project_root/$WORKERS_FILE_NAME"

  [[ -f "$project_definition_path" ]] || die "Project definition metadata is required: $project_definition_path"
  project_id="$(extract_meta_scalar "$project_definition_path" "project_id" 2>/dev/null || true)"
  project_id="$(strip_quotes "$project_id")"
  [[ -n "$project_id" ]] || die "Canonical project_id metadata is required in $project_definition_path (meta_info.project_id)."

  if [[ ! -f "$workers_path" ]]; then
    cat >"$workers_path" <<EOF
project_id: "$(escape_yaml_double_quoted_value "$project_id")"
workers:
EOF
  fi

  workers_project_id="$(extract_top_level_scalar "$workers_path" "project_id" 2>/dev/null || true)"
  workers_project_id="$(strip_quotes "$workers_project_id")"
  [[ -n "$workers_project_id" ]] || die "workers registry must contain top-level project_id: $workers_path"
  if [[ "$workers_project_id" != "$project_id" ]]; then
    die "workers registry project_id mismatch: expected '$project_id', found '$workers_project_id'."
  fi

  ensure_workers_file_shape "$workers_path"

  selected_worker_class="$(prompt_worker_class)"
  worker_uuid="$(generate_unique_worker_uuid "$workers_path")"
  registered_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  append_worker_entry "$workers_path" "$worker_uuid" "$selected_worker_class" "$registered_at"

  echo "new worker registered with uuid: $worker_uuid - copy and pass this unique id to developer so he'll register worker on he's side"
}

main "$@"
