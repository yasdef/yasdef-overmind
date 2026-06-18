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
      --help|-h)
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

  [[ "$FEATURE_PATH" = /* ]] || die "feature_path must be absolute: $FEATURE_PATH"
  [[ -d "$FEATURE_PATH" ]] || die "Feature path directory not found: $FEATURE_PATH"

  local resolved_feature_path=""
  local project_path=""
  local sibling_path=""
  local sibling_name=""

  if ! resolved_feature_path="$(cd "$FEATURE_PATH" && pwd -P)"; then
    die "Failed to resolve feature path: $FEATURE_PATH"
  fi

  project_path="$(dirname "$resolved_feature_path")"
  [[ -d "$project_path" ]] || die "Project path directory not found: $project_path"

  while IFS= read -r sibling_path; do
    [[ -n "$sibling_path" ]] || continue
    [[ "$sibling_path" != "$resolved_feature_path" ]] || continue
    [[ -f "$sibling_path/implementation_plan.md" ]] || continue
    sibling_name="$(basename "$sibling_path")"
    printf '%s\n' "$sibling_name"
  done < <(find "$project_path" -mindepth 1 -maxdepth 1 -type d -print | sort)
}

main "$@"
