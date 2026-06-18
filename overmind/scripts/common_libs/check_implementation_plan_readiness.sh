#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH=""

die() {
  echo "ERROR: $*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --feature_path)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --feature_path."
        FEATURE_PATH="$1"
        ;;
      --help | -h)
        echo "Usage: $SCRIPT_BASENAME --feature_path <abs path to feature folder>"
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done
  [[ -n "$FEATURE_PATH" ]] || die "Missing required argument: --feature_path <abs path to feature folder>."
}

main() {
  parse_args "$@"

  local plan_path="$FEATURE_PATH/implementation_plan.md"
  [[ -f "$plan_path" ]] || die "Implementation plan is not ready: required file not found: $plan_path"

  awk -v plan_path="$plan_path" '
function fail_readiness(message) {
  print "ERROR: Implementation plan is not ready: " message > "/dev/stderr"
  exit 1
}
function finalize_step() {
  if (!in_step) {
    return
  }
  if (current_repo == "") {
    fail_readiness("step " step_index " is missing #### Repo: metadata in " plan_path)
  }
}
BEGIN {
  in_step = 0
  saw_step = 0
  step_index = 0
  current_repo = ""
}
/^### Step[[:space:]]+/ {
  finalize_step()
  in_step = 1
  saw_step = 1
  step_index++
  current_repo = ""
  next
}
{
  if (!in_step) {
    next
  }
  if ($0 ~ /^#### Repo:[[:space:]]*/) {
    if (current_repo != "") {
      fail_readiness("step " step_index " declares #### Repo: more than once in " plan_path)
    }
    repo_value = tolower($0)
    sub(/^#### repo:[[:space:]]*/, "", repo_value)
    gsub(/[[:space:]]+$/, "", repo_value)
    if (!(repo_value == "backend" || repo_value == "frontend" || repo_value == "mobile")) {
      fail_readiness("step " step_index " has unsupported repo class in " plan_path ": " repo_value)
    }
    current_repo = repo_value
  }
}
END {
  finalize_step()
  if (!saw_step) {
    fail_readiness("expected at least one ### Step block in " plan_path)
  }
}
' "$plan_path"
}

main "$@"
