#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_scaffold.sh"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/feature_br_summary_TEMPLATE.md"

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

assert_equal() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_matches() {
  local value="$1"
  local pattern="$2"
  if ! printf '%s' "$value" | grep -Eq "$pattern"; then
    echo "Assertion failed: expected value to match regex '$pattern', got '$value'" >&2
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

project_type_label_for_code() {
  case "$1" in
  A) printf '%s' "New project" ;;
  B) printf '%s' "Existing project with partial context" ;;
  C) printf '%s' "Existing project with code-first context" ;;
  *) return 1 ;;
  esac
}

write_project_definition() {
  local repo_dir="$1"
  local project_type_code="${2:-B}"
  local project_type_label=""
  project_type_label="$(project_type_label_for_code "$project_type_code")"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_type_code: "$project_type_code"
  project_type_label: "$project_type_label"

steps: []
EOF_DEF
}

setup_workspace() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/asdlc/.commands" "$repo_dir/asdlc/.templates" "$repo_dir/asdlc/projects/p1"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_br_scaffold.sh"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/feature_br_summary_TEMPLATE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_br_scaffold.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  write_project_definition "$repo_dir" "B"
}

test_requires_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_scaffold.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --path <project-folder-path>."
}

test_requires_staged_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_br_scaffold.sh" "$repo_dir/feature_br_scaffold.sh"
  chmod +x "$repo_dir/feature_br_scaffold.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_br_scaffold.sh --path "$repo_dir/asdlc/projects/p1" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_path_directory_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-dir"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_scaffold.sh --path "projects/missing" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project path directory not found"
}

test_fails_when_definition_missing_in_ancestor_chain() {
  local repo_dir="$TMP_ROOT/repo-missing-definition"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/init_progress_definition.yaml"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_scaffold.sh --path "projects/p1" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: <path ancestor>/init_progress_definition.yaml"
}

test_creates_summary_from_project_metadata() {
  local repo_dir="$TMP_ROOT/repo-success"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  write_project_definition "$repo_dir" "A"

  local scaffold_rel=""
  local summary_path=""
  local out
  out="$(cd "$repo_dir/asdlc" && printf 'FTR-500\nInvoice Approval\n' | .commands/feature_br_scaffold.sh --path "projects/p1")"

  assert_contains "$out" "Created feature folder: projects/p1/"
  scaffold_rel="$(printf '%s\n' "$out" | awk '/^Updated /{sub(/^Updated /, "", $0); print $0; exit}')"
  assert_matches "$scaffold_rel" '^projects/p1/invoice_approval-[0-9]+/feature_br_summary.md$'
  summary_path="$repo_dir/asdlc/$scaffold_rel"
  assert_file_exists "$summary_path"
  assert_contains "$(cat "$summary_path")" "- feature_id: FTR-500"
  assert_contains "$(cat "$summary_path")" "- feature_title: Invoice Approval"
  assert_contains "$(cat "$summary_path")" "- project_type_code: A"
  assert_contains "$(cat "$summary_path")" "- project_type_label: New project"
}

test_requires_path_argument
test_requires_staged_location
test_fails_when_path_directory_missing
test_fails_when_definition_missing_in_ancestor_chain
test_creates_summary_from_project_metadata

echo "All BR scaffold initializer tests passed."
