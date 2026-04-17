#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-}"
REQUIREMENTS_EARS_RELATIVE_PATH="${2:-}"
TECHNICAL_REQUIREMENTS_RELATIVE_PATH="${3:-}"

REPO_MODE_HELPER_COMMAND_PATH="overmind/scripts/helper/check_prerequisite_gaps_quality.sh"
STAGED_MODE_HELPER_COMMAND_PATH=".helper/check_prerequisite_gaps_quality.sh"
HELPER_COMMAND_PATH="$REPO_MODE_HELPER_COMMAND_PATH"
WORKSPACE_ROOT=""

EXIT_CONTENT_FAILURE=1
EXIT_HELPER_FAILURE=2

helper_fail() {
  echo "ERROR: $*" >&2
  exit "$EXIT_HELPER_FAILURE"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    helper_fail "Required command not found: $command_name"
  fi
}

resolve_workspace_root() {
  local script_dir=""
  local parent_dir=""
  local root=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
  fi

  parent_dir="$(dirname "$script_dir")"
  if [[ "$(basename "$script_dir")" == ".helper" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    HELPER_COMMAND_PATH="$STAGED_MODE_HELPER_COMMAND_PATH"
    WORKSPACE_ROOT="$parent_dir"
    return 0
  fi

  require_command git
  if ! root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    helper_fail "Not a git repository at script path: $script_dir"
  fi
  HELPER_COMMAND_PATH="$REPO_MODE_HELPER_COMMAND_PATH"
  WORKSPACE_ROOT="$root"
}

resolve_target_path() {
  local workspace_root="$1"
  local target_input="$2"

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$workspace_root" "$target_input"
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

validate_prerequisite_gaps() {
  local target_path="$1"
  local requirements_path="${2:-}"
  local technical_requirements_path="${3:-}"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}

function is_unfilled(v) {
  v = trim(v)
  if (v == "" || v == "[UNFILLED]") return 1
  return 0
}

function fail_quality(msg) {
  print "quality gate failed: " msg > "/dev/stderr"
  has_errors = 1
}

BEGIN {
  has_errors = 0

  current_req = ""
  current_prereq = ""
  current_status = ""
  current_evidence = ""
  current_slice_ref = ""
  in_prereq = 0
}

function flush_prereq(    s, e, sr) {
  if (!in_prereq || current_prereq == "") return

  s = trim(current_status)
  e = trim(current_evidence)
  sr = trim(current_slice_ref)

  if (is_unfilled(s)) {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " is missing status")
  } else if (s == "unmet") {
    fail_quality("requirement " current_req " has unmet prerequisite: \"" current_prereq "\" — resolve by adding a slice to implementation_slices.md")
  } else if (s == "present_in_repo") {
    if (is_unfilled(e)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (present_in_repo) is missing evidence")
    }
  } else if (s == "scheduled_in_slices") {
    if (is_unfilled(e)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (scheduled_in_slices) is missing evidence")
    }
    if (is_unfilled(sr) || sr == "none") {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (scheduled_in_slices) is missing slice_ref")
    } else {
      all_slice_refs[sr] = current_req SUBSEP current_prereq
    }
  } else {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " has invalid status: \"" s "\"")
  }

  current_prereq = ""
  current_status = ""
  current_evidence = ""
  current_slice_ref = ""
  in_prereq = 0
}

/^### Requirement:/ {
  flush_prereq()
  line = $0
  sub(/^### Requirement:[[:space:]]*/, "", line)
  current_req = trim(line)
  in_prereq = 0
  next
}

/^#### Prerequisite:/ {
  flush_prereq()
  line = $0
  sub(/^#### Prerequisite:[[:space:]]*/, "", line)
  current_prereq = trim(line)
  in_prereq = 1
  next
}

/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/, "", line)
  current_status = trim(line)
  next
}

/^[[:space:]]*-[[:space:]]*evidence:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*evidence:[[:space:]]*/, "", line)
  current_evidence = trim(line)
  next
}

/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/, "", line)
  current_slice_ref = trim(line)
  next
}

END {
  flush_prereq()
  if (has_errors) exit 1
}
' "$target_path"

  local awk_status=$?
  if [[ "$awk_status" -ne 0 ]]; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

extract_ears_literals() {
  local requirements_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
{
  line = $0
  while (match(line, /(POST|GET|PUT|DELETE|PATCH)[[:space:]]+\/[^[:space:]`"'"'"',;.)\]]+/)) {
    tok = substr(line, RSTART, RLENGTH)
    gsub(/[[:space:]]+/, " ", tok)
    print trim(tok)
    line = substr(line, RSTART + RLENGTH)
  }
}
{
  line = $0
  while (match(line, /`\/[^`[:space:]]+`/)) {
    tok = substr(line, RSTART + 1, RLENGTH - 2)
    print trim(tok)
    line = substr(line, RSTART + RLENGTH)
  }
}
{
  line = $0
  while (match(line, /\/[a-zA-Z][a-zA-Z0-9\/_-]*/)) {
    tok = substr(line, RSTART, RLENGTH)
    if (length(tok) > 2) {
      print trim(tok)
    }
    line = substr(line, RSTART + RLENGTH)
  }
}
' "$requirements_path" | sort -u
}

extract_user_reachable_surfaces() {
  local technical_requirements_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
/^[[:space:]]*-[[:space:]]*user_reachable_surface:[[:space:]]*/ {
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*user_reachable_surface:[[:space:]]*/, "", line)
  val = trim(line)
  if (val != "" && val != "none" && val != "[UNFILLED]") {
    print val
  }
}
' "$technical_requirements_path"
}

extract_prereq_entries() {
  local target_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
/^[[:space:]]*-[[:space:]]*evidence:[[:space:]]*/ {
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*evidence:[[:space:]]*/, "", line)
  val = trim(line)
  if (val != "" && val != "[UNFILLED]") {
    print val
  }
}
/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/ {
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/, "", line)
  val = trim(line)
  if (val != "" && val != "none" && val != "[UNFILLED]") {
    print val
  }
}
' "$target_path"
}

run_literal_cross_check() {
  local target_path="$1"
  local requirements_path="$2"
  local technical_requirements_path="$3"

  local literals=""
  local surfaces=""
  local prereq_entries=""
  local literal=""
  local found=""
  local has_cross_check_errors=0

  if [[ ! -f "$requirements_path" || ! -f "$technical_requirements_path" ]]; then
    return 0
  fi

  literals="$(extract_ears_literals "$requirements_path")"
  surfaces="$(extract_user_reachable_surfaces "$technical_requirements_path")"
  prereq_entries="$(extract_prereq_entries "$target_path")"

  while IFS= read -r literal; do
    [[ -n "$literal" ]] || continue
    found=0

    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      if [[ "$entry" == *"$literal"* ]]; then
        found=1
        break
      fi
    done <<<"$prereq_entries"

    if [[ "$found" -eq 0 ]]; then
      while IFS= read -r surface; do
        [[ -n "$surface" ]] || continue
        if [[ "$surface" == *"$literal"* ]]; then
          found=1
          break
        fi
      done <<<"$surfaces"
    fi

    if [[ "$found" -eq 0 ]]; then
      echo "quality gate failed: literal \"$literal\" from requirements_ears.md is absent from both prerequisite_gaps.md entries and user_reachable_surface in technical_requirements.md" >&2
      has_cross_check_errors=1
    fi
  done <<<"$literals"

  return "$has_cross_check_errors"
}

validate_slice_refs_in_slices() {
  local target_path="$1"
  local technical_requirements_path="${2:-}"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function is_unfilled(v) {
  v = trim(v)
  if (v == "" || v == "[UNFILLED]" || v == "none") return 1
  return 0
}
function fail_quality(msg) {
  print "quality gate failed: " msg > "/dev/stderr"
  has_errors = 1
}
BEGIN {
  has_errors = 0
  current_req = ""
  current_prereq = ""
  current_status = ""
  current_slice_ref = ""
  in_prereq = 0
}
function flush_prereq(    s, sr) {
  if (!in_prereq || current_prereq == "") return
  s = trim(current_status)
  sr = trim(current_slice_ref)
  if (s == "scheduled_in_slices" && !is_unfilled(sr)) {
    if (!(sr ~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/)) {
      fail_quality("slice_ref \"" sr "\" in requirement " current_req " prerequisite \"" current_prereq "\" does not match required format [A-Za-z0-9][A-Za-z0-9_.-]*")
    }
  }
  in_prereq = 0
  current_prereq = ""
  current_status = ""
  current_slice_ref = ""
}
/^### Requirement:/ {
  flush_prereq()
  line = $0
  sub(/^### Requirement:[[:space:]]*/, "", line)
  current_req = trim(line)
  next
}
/^#### Prerequisite:/ {
  flush_prereq()
  line = $0
  sub(/^#### Prerequisite:[[:space:]]*/, "", line)
  current_prereq = trim(line)
  in_prereq = 1
  next
}
/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/, "", line)
  current_status = trim(line)
  next
}
/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/, "", line)
  current_slice_ref = trim(line)
  next
}
END {
  flush_prereq()
  if (has_errors) exit 1
}
' "$target_path"
}

main() {
  require_command awk
  require_command sed

  resolve_workspace_root

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $HELPER_COMMAND_PATH <prerequisite_gaps.md> [requirements_ears.md] [technical_requirements.md]"
  fi

  local target_path=""
  local requirements_path=""
  local technical_requirements_path=""

  target_path="$(resolve_target_path "$WORKSPACE_ROOT" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target prerequisite gaps artifact not found: $TARGET_RELATIVE_PATH"
  fi
  if [[ ! -s "$target_path" ]]; then
    echo "target prerequisite gaps artifact is empty: $TARGET_RELATIVE_PATH" >&2
    exit "$EXIT_CONTENT_FAILURE"
  fi

  local has_errors=0

  validate_prerequisite_gaps "$target_path" || has_errors=1

  if [[ -n "$REQUIREMENTS_EARS_RELATIVE_PATH" && -n "$TECHNICAL_REQUIREMENTS_RELATIVE_PATH" ]]; then
    requirements_path="$(resolve_target_path "$WORKSPACE_ROOT" "$REQUIREMENTS_EARS_RELATIVE_PATH")"
    technical_requirements_path="$(resolve_target_path "$WORKSPACE_ROOT" "$TECHNICAL_REQUIREMENTS_RELATIVE_PATH")"

    if [[ -f "$requirements_path" && -f "$technical_requirements_path" ]]; then
      run_literal_cross_check "$target_path" "$requirements_path" "$technical_requirements_path" || has_errors=1
    fi
  fi

  validate_slice_refs_in_slices "$target_path" || has_errors=1

  if [[ "$has_errors" -ne 0 ]]; then
    exit "$EXIT_CONTENT_FAILURE"
  fi

  echo "quality gate passed"
}

main "$@"
