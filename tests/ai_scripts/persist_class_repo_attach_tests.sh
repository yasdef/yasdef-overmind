#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_SETUP_COMMON_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/project_setup_common.sh"
PERSIST_CLASS_REPO_ATTACH_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/persist_class_repo_attach.sh"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Assertion failed: expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero status" >&2
    exit 1
  fi
}

setup_git_repo() {
  local repo_path="$1"
  mkdir -p "$repo_path"
  git -C "$repo_path" init >/dev/null 2>&1
}

setup_attach_lib_with_failing_guard() {
  local lib_dir="$1"
  mkdir -p "$lib_dir"
  cp "$PROJECT_SETUP_COMMON_SRC" "$lib_dir/project_setup_common.sh"
  cp "$PERSIST_CLASS_REPO_ATTACH_SRC" "$lib_dir/persist_class_repo_attach.sh"
  chmod +x "$lib_dir/persist_class_repo_attach.sh"

  cat >"$lib_dir/class_repo_paths.sh" <<'OUT'
#!/usr/bin/env bash

class_repo_paths_validate_coherence() {
  echo "validator stub: written record is incoherent" >&2
  return 1
}
OUT
}

write_project_definition() {
  local project_dir="$1"

  cat >"$project_dir/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_classes:
    - backend
  project_type_code: "A"
  class_repo_paths:
    backend:
      state: "deferred"

steps: []
OUT
}

test_attach_fails_when_post_write_guard_fails() {
  local lib_dir="$TMP_ROOT/common_libs"
  local project_dir="$TMP_ROOT/project"
  local repo_path="$TMP_ROOT/backend-repo"
  local out=""
  local status=0

  setup_attach_lib_with_failing_guard "$lib_dir"
  mkdir -p "$project_dir"
  setup_git_repo "$repo_path"
  write_project_definition "$project_dir"

  set +e
  out="$("$lib_dir/persist_class_repo_attach.sh" "$project_dir" "backend" "$repo_path" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "validator stub: written record is incoherent"
  assert_contains "$(cat "$project_dir/init_progress_definition.yaml")" "state: \"ready\""
}

test_attach_fails_when_post_write_guard_fails

echo "All persist_class_repo_attach tests passed."
