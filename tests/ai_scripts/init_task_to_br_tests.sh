#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_task_to_br.sh"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_task_to_br_quality.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/task_to_br_rule.md"
PHASE2_RULE_SRC="$SOURCE_ROOT/overmind/rules/user_br_clarification_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/missing_br_data_TEMPLATE.md"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/missing_br_data_GOLDEN_EXAMPLE.md"

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
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_task_to_br.sh"
  cp "$HELPER_SRC" "$repo_dir/asdlc/.helper/check_task_to_br_quality.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/task_to_br_rule.md"
  cp "$PHASE2_RULE_SRC" "$repo_dir/asdlc/.rules/user_br_clarification_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/missing_br_data_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/missing_br_data_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_task_to_br.sh" "$repo_dir/asdlc/.helper/check_task_to_br_quality.sh"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
task_to_br | codex | gpt-5.4 | --config | model_reasoning_effort='high'
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
- feature_id: FTR-42
- feature_title: Invoice approval baseline
- project_type_code: B
- source_type: [UNFILLED]
- last_updated: [UNFILLED]
- ready_to_ears: false
OUT

  cat >"$repo_dir/asdlc/projects/p1/feature-a/epic_story_input.md" <<'OUT'
As a product owner I want a clear invoice approval baseline.
OUT

  (
    cd "$repo_dir/asdlc"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "seed" >README.md
    git add .
    git commit -qm "seed"
  )
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

cat >"$feature_root/feature_br_summary.md" <<'DOC'
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: B
- source_type: User input
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_task_to_br.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_task_to_br.sh" "$repo_dir/feature_task_to_br.sh"
  chmod +x "$repo_dir/feature_task_to_br.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_task_to_br.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/feature_br_summary.md"
}

test_updates_feature_with_user_input() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/capture-success"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local out
  out="$(
    cd "$repo_dir/asdlc"
    printf "epic_story_input.md\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "Target artifact: projects/p1/feature-a/feature_br_summary.md"
}

test_requires_feature_path_argument
test_requires_staged_location
test_fails_when_feature_summary_missing
test_updates_feature_with_user_input

echo "All task-to-BR initializer tests passed."
