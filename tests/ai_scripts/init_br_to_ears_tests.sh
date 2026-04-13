#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_to_ears.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/br_to_ears.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/reqirements_ears_TEMPLATE.md"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md"

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
    echo "Assertion failed: expected output to NOT contain: $needle" >&2
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

assert_file_not_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

setup_workspace_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_br_to_ears.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/br_to_ears.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/reqirements_ears_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_br_to_ears.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT
}

setup_models_file() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'EOF_MODELS'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
br_to_ears | codex | gpt-5.4 | --config | model_reasoning_effort='high'
EOF_MODELS
}

write_quality_gate_stub() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.helper/check_requirements_ears_quality.sh" <<'EOF_HELPER'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

if [[ "${TEST_QUALITY_HELPER_FAIL:-0}" == "1" ]]; then
  echo "ears quality gate failed in helper"
  exit 1
fi

echo "quality gate passed"
EOF_HELPER
  chmod +x "$repo_dir/asdlc/.helper/check_requirements_ears_quality.sh"
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'EOF_CODEX'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_REQUIREMENTS_FILE:-projects/p1/feature-a/requirements_ears.md}"
printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - Generate EARS spec
**User Story:** As a product owner, I want EARS requirements, so that implementation is deterministic.

**Acceptance Criteria (EARS):**
- WHEN BR-to-EARS step runs, THE System SHALL produce requirements_ears.md for the selected feature path.

**Verification:** Script integration test validates file output and commit behavior.
OUT
EOF_CODEX
  chmod +x "$repo_dir/bin/codex"
}

seed_feature_br_summary() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  local ready_value="${3:-true}"
  mkdir -p "$repo_dir/asdlc/$feature_path"
  cat >"$repo_dir/asdlc/$feature_path/feature_br_summary.md" <<EOF_BR
# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: FTR-9000
- source_type: Repository scan
- last_updated: 2026-03-24
- ready_to_ears: $ready_value
EOF_BR
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_feature_br_summary "$repo_dir"

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

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_to_ears.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_br_to_ears.sh" "$repo_dir/feature_br_to_ears.sh"
  chmod +x "$repo_dir/feature_br_to_ears.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_br_to_ears.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_readiness_not_true() {
  local repo_dir="$TMP_ROOT/repo-readiness-fail"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "projects/p1/feature-a" "false"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Expected ready_to_ears: true"
  assert_contains "$out" "feature_br_check_ears_readiness.sh"
  assert_file_not_exists "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md"
}

test_fails_when_required_file_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-required-file"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.rules/br_to_ears.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .rules/br_to_ears.md"
}

test_fails_when_br_to_ears_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-model-phase"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'EOF_MODELS_MISSING'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
repo_analyse | codex | gpt-5.4
EOF_MODELS_MISSING

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'br_to_ears' entry"
}

test_does_not_run_quality_helper_directly() {
  local repo_dir="$TMP_ROOT/repo-quality-gate-model-owned"
  local capture_dir="$TMP_ROOT/capture-quality-gate-model-owned"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_QUALITY_HELPER_FAIL=1 .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a"
  )"
  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "quality gate command"
  assert_contains "$codex_prompt" "check_requirements_ears_quality.sh projects/p1/feature-a/requirements_ears.md"
}

test_runs_codex_and_commits_only_requirements_file() {
  local repo_dir="$TMP_ROOT/repo-success-default"
  local capture_dir="$TMP_ROOT/capture-success-default"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local br_before
  br_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  echo "local-change" >>"$repo_dir/asdlc/README.md"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/br_to_ears.md"
  assert_contains "$codex_prompt" "Read-only BR summary source: projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$codex_prompt" "Target EARS artifact: projects/p1/feature-a/requirements_ears.md"
  assert_contains "$codex_prompt" "Template file: .templates/reqirements_ears_TEMPLATE.md"
  assert_contains "$codex_prompt" "Golden example file: .golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md"

  local br_after
  br_after="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  assert_equal "$br_before" "$br_after"

  assert_equal "Generate overmind requirements ears" "$(git -C "$repo_dir/asdlc" log -1 --pretty=%s)"
  local committed_files
  committed_files="$(git -C "$repo_dir/asdlc" show --name-only --pretty='' HEAD)"
  assert_contains "$committed_files" "projects/p1/feature-a/requirements_ears.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/feature_br_summary.md"
  assert_not_contains "$committed_files" "README.md"
}

test_skips_empty_commit_when_output_is_unchanged() {
  local repo_dir="$TMP_ROOT/repo-empty-commit-skip"
  local capture_dir="$TMP_ROOT/capture-empty-commit-skip"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  local commits_after_first
  commits_after_first="$(git -C "$repo_dir/asdlc" rev-list --count HEAD)"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_br_to_ears.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  local commits_after_second
  commits_after_second="$(git -C "$repo_dir/asdlc" rev-list --count HEAD)"

  assert_equal "$commits_after_first" "$commits_after_second"
}

test_runs_with_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-success-override"
  local capture_dir="$TMP_ROOT/capture-success-override"
  local feature_path="projects/p1/custom-folder"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_feature_br_summary "$repo_dir" "$feature_path" "true"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_REQUIREMENTS_FILE="$feature_path/requirements_ears.md" \
      .commands/feature_br_to_ears.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "Updated $feature_path/requirements_ears.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/requirements_ears.md"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Read-only BR summary source: $feature_path/feature_br_summary.md"
  assert_contains "$codex_prompt" "Target EARS artifact: $feature_path/requirements_ears.md"
  assert_not_contains "$codex_prompt" "Target EARS artifact: projects/p1/feature-a/requirements_ears.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_readiness_not_true
test_fails_when_required_file_is_missing
test_fails_when_br_to_ears_model_phase_missing
test_does_not_run_quality_helper_directly
test_runs_codex_and_commits_only_requirements_file
test_skips_empty_commit_when_output_is_unchanged
test_runs_with_absolute_feature_path

echo "All BR-to-EARS initializer tests passed."
