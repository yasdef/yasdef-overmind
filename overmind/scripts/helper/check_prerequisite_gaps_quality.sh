#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-}"
REQUIREMENTS_EARS_RELATIVE_PATH="${2:-}"
TECHNICAL_REQUIREMENTS_RELATIVE_PATH="${3:-}"

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

resolve_target_path() {
  local target_input="$1"

  [[ -n "$target_input" ]] || helper_fail "Missing target artifact path."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
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

function is_none(v) {
  v = tolower(trim(v))
  return (v == "none")
}

function is_scheduled_in_feature(v) {
  v = trim(v)
  return (v ~ "^scheduled_in_feature[[:space:]]+[^/[:space:]]+/[^[:space:]]+$")
}

function looks_like_surface_identity(v, lower_v) {
  lower_v = tolower(trim(v))
  if (lower_v ~ /(route|page|screen|shell|login|sign-in|signin|workspace|entry|portal|console|ui|view|lookup|search|dashboard|form|command|cli|job|endpoint|tool|http|post |get |put |patch |delete |deep link|deeplink)/) return 1
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
  current_surface_kind = ""
  current_surface_identity = ""
  current_evidence = ""
  current_slice_ref = ""
  in_prereq = 0
}

function flush_prereq(    s, sk, si, e, sr) {
  if (!in_prereq || current_prereq == "") return

  s = trim(current_status)
  sk = trim(current_surface_kind)
  si = trim(current_surface_identity)
  e = trim(current_evidence)
  sr = trim(current_slice_ref)

  if (is_unfilled(sk)) {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " is missing surface_kind")
  } else if (sk != "required_missing_user_reachable_surface" && sk != "present_user_reachable_surface" && sk != "transport_or_internal_execution_gap") {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " has invalid surface_kind: \"" sk "\"")
  }

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
  } else if (is_scheduled_in_feature(s)) {
    if (is_unfilled(e)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (" s ") is missing evidence")
    }
    if (!is_unfilled(sr) && sr != "none") {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (" s ") must use slice_ref: none")
    }
  } else {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " has invalid status: \"" s "\"")
  }

  if (sk == "required_missing_user_reachable_surface") {
    if (s != "unmet" && s != "scheduled_in_slices" && !is_scheduled_in_feature(s)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " uses required_missing_user_reachable_surface but status is not unmet/scheduled_in_slices/scheduled_in_feature")
    }
    if (is_unfilled(si) || is_none(si)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (required_missing_user_reachable_surface) is missing surface_identity")
    } else if (!looks_like_surface_identity(si)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " has non-operator-facing surface_identity: \"" si "\"")
    }
  } else if (sk == "present_user_reachable_surface") {
    if (s != "present_in_repo") {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " uses present_user_reachable_surface but status is not present_in_repo")
    }
    if (!is_unfilled(si) && !is_none(si)) {
      fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " (present_user_reachable_surface) must use surface_identity: none")
    }
  } else if (sk == "transport_or_internal_execution_gap") {
    fail_quality("prerequisite \"" current_prereq "\" in requirement " current_req " is classified as transport_or_internal_execution_gap; keep transport/internal gaps out of prerequisite entries")
  }

  current_prereq = ""
  current_status = ""
  current_surface_kind = ""
  current_surface_identity = ""
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

/^[[:space:]]*-[[:space:]]*surface_kind:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*surface_kind:[[:space:]]*/, "", line)
  current_surface_kind = trim(line)
  next
}

/^[[:space:]]*-[[:space:]]*surface_identity:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*surface_identity:[[:space:]]*/, "", line)
  current_surface_identity = trim(line)
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

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $(basename "$0") <prerequisite_gaps.md> [requirements_ears.md] [technical_requirements.md]"
  fi

  local target_path=""
  local requirements_path=""
  local technical_requirements_path=""

  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

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
    requirements_path="$(resolve_target_path "$REQUIREMENTS_EARS_RELATIVE_PATH")"
    technical_requirements_path="$(resolve_target_path "$TECHNICAL_REQUIREMENTS_RELATIVE_PATH")"

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
