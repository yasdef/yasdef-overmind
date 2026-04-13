#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-}"

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

resolve_repo_root() {
  local script_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
  fi

  if ! git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null; then
    helper_fail "Not a git repository at script path: $script_dir"
  fi
}

resolve_target_path() {
  local repo_root="$1"
  local target_input="$2"

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$repo_root" "$target_input"
}

validate_content() {
  local target_path="$1"
  local status=0

  set +e
  awk '
BEGIN {
  in_block = 0
  in_ears = 0
  block_count = 0
  has_errors = 0
  current_heading = ""

  block_has_user_story = 0
  block_has_ears = 0
  block_has_verification = 0
  block_ears_bullet_count = 0
  block_valid_ears_bullet_count = 0

  req_last = 0
  nfr_last = 0
}

function start_block(heading) {
  in_block = 1
  in_ears = 0
  block_count++
  current_heading = heading
  block_has_user_story = 0
  block_has_ears = 0
  block_has_verification = 0
  block_ears_bullet_count = 0
  block_valid_ears_bullet_count = 0
}

function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}

function is_allowed_ears_pattern(bullet, upper) {
  upper = toupper(bullet)

  if (upper ~ /^THE .+ SHALL .+/) {
    return 1
  }
  if (upper ~ /^WHEN .+ AND WHILE .+, THE .+ SHALL .+/) {
    return 1
  }
  if (upper ~ /^WHEN .+, THE .+ SHALL .+/) {
    return 1
  }
  if (upper ~ /^IF .+, THEN THE .+ SHALL .+/) {
    return 1
  }
  if (upper ~ /^WHILE .+, THE .+ SHALL .+/) {
    return 1
  }
  if (upper ~ /^WHERE .+, THE .+ SHALL .+/) {
    return 1
  }

  return 0
}

function finish_block() {
  if (!in_block) {
    return
  }

  if (!block_has_user_story) {
    fail_quality("missing User Story in block: " current_heading)
  }

  if (!block_has_ears) {
    fail_quality("missing Acceptance Criteria (EARS) in block: " current_heading)
  } else {
    if (block_ears_bullet_count == 0) {
      fail_quality("no acceptance-criteria bullets in block: " current_heading)
    }
    if (block_valid_ears_bullet_count == 0) {
      fail_quality("no valid EARS-pattern bullets in block: " current_heading)
    }
  }

  if (!block_has_verification) {
    fail_quality("missing Verification in block: " current_heading)
  }

  in_ears = 0
}

/^### (Requirement|NFR) [0-9]+([[:space:]]|$)/ {
  finish_block()

  heading_type = $2
  heading_id = $3 + 0

  if (heading_type == "Requirement") {
    if (heading_id in req_seen) {
      fail_quality("duplicate Requirement numbering: " heading_id)
    }
    req_seen[heading_id] = 1

    if (req_last == 0 && heading_id != 1) {
      fail_quality("Requirement numbering must start at 1; found " heading_id)
    }
    if (req_last > 0 && heading_id != req_last + 1) {
      fail_quality("Requirement numbering must be sequential; expected " (req_last + 1) ", found " heading_id)
    }
    req_last = heading_id
  } else {
    if (heading_id in nfr_seen) {
      fail_quality("duplicate NFR numbering: " heading_id)
    }
    nfr_seen[heading_id] = 1

    if (nfr_last == 0 && heading_id != 1) {
      fail_quality("NFR numbering must start at 1; found " heading_id)
    }
    if (nfr_last > 0 && heading_id != nfr_last + 1) {
      fail_quality("NFR numbering must be sequential; expected " (nfr_last + 1) ", found " heading_id)
    }
    nfr_last = heading_id
  }

  start_block($0)
  next
}

{
  if (!in_block) {
    next
  }

  if ($0 ~ /^\*\*User Story:\*\*/) {
    block_has_user_story = 1
    next
  }

  if ($0 ~ /^\*\*Acceptance Criteria \(EARS\):\*\*/) {
    block_has_ears = 1
    in_ears = 1
    next
  }

  if ($0 ~ /^\*\*Verification:\*\*/) {
    block_has_verification = 1
    in_ears = 0
    next
  }

  if (in_ears && $0 ~ /^[[:space:]]*-[[:space:]]+/) {
    bullet = $0
    sub(/^[[:space:]]*-[[:space:]]+/, "", bullet)
    block_ears_bullet_count++

    if (!is_allowed_ears_pattern(bullet)) {
      fail_quality("invalid EARS bullet pattern in block " current_heading ": " bullet)
      next
    }

    block_valid_ears_bullet_count++

  }
}

END {
  finish_block()

  if (block_count == 0) {
    fail_quality("no Requirement/NFR blocks found")
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: EARS requirements structure is complete"
}
' "$target_path"
  status=$?
  set -e

  case "$status" in
  0)
    return 0
    ;;
  1)
    return "$EXIT_CONTENT_FAILURE"
    ;;
  *)
    helper_fail "Validation runtime failure for $target_path (awk exit $status)."
    ;;
  esac
}

main() {
  require_command git
  require_command awk
  require_command grep

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Missing target requirements path argument."
  fi

  local repo_root=""
  repo_root="$(resolve_repo_root)"

  local target_path=""
  target_path="$(resolve_target_path "$repo_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target EARS requirements not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target EARS requirements is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  if ! validate_content "$target_path"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi

  exit 0
}

main "$@"
