#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_user_br_clarification.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/user_br_clarification_rule.md"

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
  mkdir -p "$repo_dir/asdlc/.commands" "$repo_dir/asdlc/.rules" "$repo_dir/asdlc/.setup" "$repo_dir/asdlc/.helper" "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_user_br_clarification.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/user_br_clarification_rule.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_user_br_clarification.sh"

  cat >"$repo_dir/asdlc/.helper/check_task_to_br_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail
exit 0
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_task_to_br_quality.sh"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
user_br_clarification | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  cat >"$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: B
- source_type: User input
- last_updated: 2026-04-06
- ready_to_ears: false
OUT

  cat >"$repo_dir/asdlc/projects/p1/feature-a/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Need legal confirmation.

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
feature_root="${TEST_FEATURE_ROOT:?TEST_FEATURE_ROOT must be set}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

cat >"$feature_root/missing_br_data.md" <<'DOC'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Need legal confirmation.

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_user_br_clarification.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_user_br_clarification.sh" "$repo_dir/feature_user_br_clarification.sh"
  chmod +x "$repo_dir/feature_user_br_clarification.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_user_br_clarification.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_feature_summary_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-summary"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_user_br_clarification.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/feature_br_summary.md"
}

test_processes_unresolved_items() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/capture-success"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local out
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_user_br_clarification.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Processed projects/p1/feature-a/missing_br_data.md via user BR clarification."
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/missing_br_data.md")" "rised=true"
}

test_skips_when_only_template_example_mentions_rised_false() {
  local repo_dir="$TMP_ROOT/repo-template-example-skip"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/projects/p1/feature-a/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
> Use deterministic format:
> `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
OUT

  local out
  out="$(
    cd "$repo_dir/asdlc"
    .commands/feature_user_br_clarification.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "No non-rised items found in projects/p1/feature-a/missing_br_data.md"
}

test_requires_feature_path_argument
test_requires_staged_location
test_fails_when_feature_summary_missing
test_processes_unresolved_items
test_skips_when_only_template_example_mentions_rised_false

echo "All user BR clarification initializer tests passed."
