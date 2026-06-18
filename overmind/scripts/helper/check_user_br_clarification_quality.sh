#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-overmind/product/feature_br_summary.md}"

helper_error() {
  echo "helper error: $*" >&2
  exit 2
}

resolve_target_path() {
  local target_input="$1"

  [[ -n "$target_input" ]] || helper_error "Missing target artifact path."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
}

missing_data_has_non_rised_items() {
  local missing_data_path="$1"

  awk '
BEGIN {
  in_unresolved_ledger = 0
  has_non_rised = 0
}
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
/^##[[:space:]]+/ {
  heading = trim($0)
  in_unresolved_ledger = (heading ~ /^##[[:space:]]+3\.[[:space:]]+Unresolved[[:space:]]+Items[[:space:]]+Ledger[[:space:]]+\(Rised\)[[:space:]]*$/)
  next
}
{
  if (!in_unresolved_ledger) {
    next
  }

  lowered = tolower(trim($0))
  if (lowered !~ /^-[[:space:]]*rised_item_[0-9]+:[[:space:]]*/) {
    next
  }

  if (lowered ~ /non-rised|not-rised|rised[[:space:]]*=[[:space:]]*false|rised:[[:space:]]*false/) {
    has_non_rised = 1
    next
  }

  if (lowered !~ /rised[[:space:]]*=[[:space:]]*true/ && lowered !~ /rised:[[:space:]]*true/) {
    has_non_rised = 1
  }
}
END {
  exit(has_non_rised ? 0 : 1)
}
' "$missing_data_path"
}

main() {
  local script_dir=""
  local base_helper=""
  local target_path=""
  local missing_data_path=""
  local base_output=""
  local base_status=0

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; then
    helper_error "Failed to resolve helper directory."
  fi
  base_helper="$script_dir/check_task_to_br_quality.sh"
  [[ -x "$base_helper" ]] || helper_error "Required helper not found or not executable: $base_helper"

  set +e
  base_output="$("$base_helper" "$TARGET_RELATIVE_PATH" 2>&1)"
  base_status=$?
  set -e

  if [[ "$base_status" -ne 0 ]]; then
    printf '%s\n' "$base_output"
    exit "$base_status"
  fi

  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"
  missing_data_path="$(dirname "$target_path")/missing_br_data.md"
  if [[ -f "$missing_data_path" ]] && missing_data_has_non_rised_items "$missing_data_path"; then
    echo "business-context gate failed"
    echo "missing: missing_br_data.md -> unresolved user BR clarification items remain; continue until every rised_item_N is rised=true"
    exit 1
  fi

  printf '%s\n' "$base_output"
}

main "$@"
