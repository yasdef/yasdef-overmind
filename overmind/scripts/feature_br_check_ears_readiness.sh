#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
FEATURE_BR_FILE=""
PRODUCT_DIR=""
USER_INPUT_HELPER=".helper/check_task_to_br_quality.sh"
REPO_HELPER=".helper/check_business_context_filled_from_repo.sh"

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

  if ! git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "ASDLC workspace is not a git repository: $parent_dir"
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

set_artifact_paths() {
  PRODUCT_DIR="$FEATURE_PATH"
  FEATURE_BR_FILE="$PRODUCT_DIR/feature_br_summary.md"
}

ensure_required_files() {
  local runtime_root="$1"
  local required_paths=(
    "$FEATURE_BR_FILE"
    "$USER_INPUT_HELPER"
    "$REPO_HELPER"
  )
  local relative_path=""

  for relative_path in "${required_paths[@]}"; do
    if [[ ! -f "$runtime_root/$relative_path" ]]; then
      die "Required file not found: $relative_path"
    fi
  done
}

extract_meta_value() {
  local feature_br_path="$1"
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
/^##[[:space:]]+/ {
  heading = trim($0)
  in_meta = (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/)
  next
}
{
  if (!in_meta) {
    next
  }

  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
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
' "$feature_br_path"
}

run_helper_gate() {
  local helper_path="$1"
  local feature_br_path="$2"
  local failure_message="$3"
  local helper_output=""
  local helper_status=0

  set +e
  helper_output="$("$helper_path" "$feature_br_path" 2>&1)"
  helper_status=$?
  set -e

  if [[ "$helper_status" -eq 0 ]]; then
    return 0
  fi

  if [[ -n "$helper_output" ]]; then
    die "$failure_message Helper output: $helper_output"
  fi
  die "$failure_message"
}

update_ready_to_ears() {
  local feature_br_path="$1"
  local ready_value=""
  local tmp_output=""

  if ! ready_value="$(extract_meta_value "$feature_br_path" "ready_to_ears")"; then
    die "Missing key ready_to_ears in ## 1. Document Meta: $FEATURE_BR_FILE"
  fi
  if [[ "$ready_value" != "false" ]]; then
    die "Expected ready_to_ears to be false before readiness check; found '$ready_value'."
  fi

  tmp_output="$(mktemp)"
  if ! awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
BEGIN {
  in_meta = 0
  updated = 0
}
/^##[[:space:]]+/ {
  heading = trim($0)
  in_meta = (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/)
  print
  next
}
{
  line = $0
  if (in_meta) {
    candidate = line
    sub(/^[[:space:]]*-[[:space:]]*/, "", candidate)
    colon_index = index(candidate, ":")
    if (colon_index > 0) {
      key = trim(substr(candidate, 1, colon_index - 1))
      if (key == "ready_to_ears") {
        sub(/:[[:space:]]*.*/, ": true", line)
        updated = 1
      }
    }
  }
  print line
}
END {
  exit(updated ? 0 : 1)
}
' "$feature_br_path" >"$tmp_output"; then
    rm -f "$tmp_output"
    die "Failed to update ready_to_ears in $FEATURE_BR_FILE."
  fi

  if ! mv "$tmp_output" "$feature_br_path"; then
    rm -f "$tmp_output"
    die "Failed to write $FEATURE_BR_FILE."
  fi
}

commit_feature_artifacts_if_changed() {
  local repo_root="$1"

  if ! git -C "$repo_root" add --all -- "$PRODUCT_DIR"; then
    die "Failed to stage changes under $PRODUCT_DIR."
  fi

  if git -C "$repo_root" diff --cached --quiet -- "$PRODUCT_DIR"; then
    return 0
  fi

  if ! git -C "$repo_root" commit -m "Mark feature BR ready to EARS" -- "$PRODUCT_DIR" >/dev/null 2>&1; then
    die "Failed to commit changes under $PRODUCT_DIR before finish."
  fi
}

main() {
  require_command git
  require_command awk
  require_command mv

  parse_args "$@"

  local runtime_root=""
  local feature_br_path=""
  local user_input_helper_path=""
  local repo_helper_path=""

  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  set_artifact_paths
  ensure_required_files "$runtime_root"

  feature_br_path="$runtime_root/$FEATURE_BR_FILE"
  user_input_helper_path="$runtime_root/$USER_INPUT_HELPER"
  repo_helper_path="$runtime_root/$REPO_HELPER"

  run_helper_gate \
    "$user_input_helper_path" \
    "$feature_br_path" \
    "User-input business-context check failed."

  run_helper_gate \
    "$repo_helper_path" \
    "$feature_br_path" \
    "Repository business-context check failed."

  update_ready_to_ears "$feature_br_path"
  commit_feature_artifacts_if_changed "$runtime_root"

  echo "EARS readiness check passed."
}

main "$@"
