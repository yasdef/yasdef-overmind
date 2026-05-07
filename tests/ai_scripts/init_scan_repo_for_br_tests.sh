#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_scan_repo_for_br.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/repo_br_scan_rule.md"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_business_context_filled_from_repo.sh"

TMP_ROOT="$(mktemp -d)"
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "Assertion failed: expected output to not contain: $needle" >&2
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

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Assertion failed: expected file to exist: $path" >&2
    exit 1
  fi
}

setup_workspace() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/projects/p1/feature-a" \
    "$repo_dir/repositories/backend" \
    "$repo_dir/repositories/frontend"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/repo_br_scan_rule.md"
  cp "$HELPER_SRC" "$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh"
  chmod +x "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh" "$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
repo_analyse | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  echo "backend" >"$repo_dir/repositories/backend/README.md"
  echo "frontend" >"$repo_dir/repositories/frontend/README.md"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "ready"
      path: "$repo_dir/repositories/frontend"
    infrastructure:
      state: "deferred"
      path: ""

steps: []
EOF
}

seed_feature_br_summary() {
  local repo_dir="$1"
  local project_type_code="$2"
  cat >"$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" <<EOF_SUMMARY
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: $project_type_code
- ready_to_ears: false
EOF_SUMMARY
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
feature_root="${TEST_FEATURE_ROOT:?TEST_FEATURE_ROOT must be set}"
target_file="$feature_root/feature_br_summary.md"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"
cat >"$target_file" <<'DOC'
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: B
- source_type: Repository scan
- last_updated: 2026-04-06
- ready_to_ears: false
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh" "$repo_dir/feature_scan_repo_for_br.sh"
  chmod +x "$repo_dir/feature_scan_repo_for_br.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_scan_repo_for_br.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_feature_summary_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-summary"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/feature_br_summary.md"
}

test_fails_for_project_type_a() {
  local repo_dir="$TMP_ROOT/repo-type-a"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "A"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "for new projects repo scan not applicable"
}

test_type_a_short_circuits_before_repo_path_validation() {
  local repo_dir="$TMP_ROOT/repo-type-a-deferred-paths"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "A"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
    frontend:
      state: "deferred"
      path: ""

steps: []
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "for new projects repo scan not applicable"
  assert_not_contains "$out" "No usable repository paths found in meta_info.class_repo_paths"
}

test_fails_when_no_usable_repo_paths() {
  local repo_dir="$TMP_ROOT/repo-no-usable-repo-paths"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
    frontend:
      state: "deferred"
      path: ""

steps: []
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "No usable repository paths found in meta_info.class_repo_paths"
}

test_runs_codex_and_updates_feature_summary() {
  local repo_dir="$TMP_ROOT/repo-type-b"
  local capture_dir="$TMP_ROOT/capture-type-b"
  local backend_repo=""
  local frontend_repo=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd)"
  frontend_repo="$(cd "$repo_dir/repositories/frontend" && pwd)"

  local out
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "Target artifact: projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- backend: $backend_repo"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- frontend: $frontend_repo"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- source_type: Repository scan"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_feature_summary_missing
test_fails_for_project_type_a
test_type_a_short_circuits_before_repo_path_validation
test_fails_when_no_usable_repo_paths
test_runs_codex_and_updates_feature_summary

echo "All repo BR scan initializer tests passed."
