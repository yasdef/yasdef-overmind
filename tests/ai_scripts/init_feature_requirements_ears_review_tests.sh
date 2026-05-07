#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_requirements_ears_review.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/requirements_ears_review_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/requirements_ears_review_TEMPLATE.md"
GOLDEN_EXAMPLE_SRC="$SOURCE_ROOT/overmind/golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"

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
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_requirements_ears_review.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/requirements_ears_review_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/requirements_ears_review_TEMPLATE.md"
  cp "$GOLDEN_EXAMPLE_SRC" "$repo_dir/asdlc/.golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_requirements_ears_review.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT
}

setup_models_file() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
requirements_ears_review | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

write_quality_gate_stub() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.helper/check_requirements_ears_review_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

if [[ "${TEST_QUALITY_HELPER_FAIL:-0}" == "1" ]]; then
  echo "requirements ears review quality gate failed in helper"
  exit 1
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_requirements_ears_review_quality.sh"
}

seed_feature_sources() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Moderation workspace access
- project_type_code: B
- source_type: User input
- last_updated: 2026-04-11
- ready_to_ears: true

## 7. Business Rules and Decision Logic
- BR-1: Only ACTIVE admins may use moderation workspace data and actions after authentication.

## 15. Open Questions
- none
OUT

  cat >"$repo_dir/asdlc/$feature_path/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - Existing access rule
**User Story:** As an admin, I want workspace access rules, so that moderation is controlled.

**Acceptance Criteria (EARS):**
- WHEN an ACTIVE admin opens the moderation workspace, THE System SHALL return the workspace shell.

**Verification:** Integration test for moderation workspace bootstrap.
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_requirements="${TARGET_REQUIREMENTS_FILE:-projects/p1/feature-a/requirements_ears.md}"
target_review="${TARGET_REVIEW_FILE:-projects/p1/feature-a/requirements_ears_review.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_requirements")" "$(dirname "$target_review")"
cat >"$target_requirements" <<'REQS'
# Requirements (EARS)

## Requirements

### Requirement 1 - Existing access rule
**User Story:** As an admin, I want workspace access rules, so that moderation is controlled.

**Acceptance Criteria (EARS):**
- WHEN an ACTIVE admin opens the moderation workspace, THE System SHALL return the workspace shell.
- IF an authenticated admin is not in ACTIVE status, THEN THE System SHALL deny access to moderation workspace data and actions.

**Verification:** Integration test for moderation workspace bootstrap and ACTIVE guard behavior.
REQS

cat >"$target_review" <<'REVIEW'
# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Feature review test
- source_feature_br_summary: projects/p1/feature-a/feature_br_summary.md
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.
- pending_state: escalated
- allowed_severity: High, Medium, Low
- user_question_format: Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.

## 3. Findings Ledger
### Finding 1 - ACTIVE status must guard workspace APIs
- severity: Medium
- state: added to ears
- source_br_summary_reference: feature_br_summary.md -> business rules and access control notes
- related_requirement_targets: Requirement 1
- gap_summary: ACTIVE was not enforced after authentication.
- recommendation: Add explicit ACTIVE guard behavior for non-ACTIVE authenticated admins.
- suggested_ears_change: Update Requirement 1 with a post-auth guard statement.
- user_prompt: Here is the finding: ACTIVE was not enforced after authentication. I would recommend: add an explicit ACTIVE guard statement in requirements_ears.md. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added an explicit ACTIVE guard statement to requirements_ears.md.
REVIEW
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_feature_sources "$repo_dir"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_requirements_ears_review.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_requirements_ears_review.sh" "$repo_dir/feature_requirements_ears_review.sh"
  chmod +x "$repo_dir/feature_requirements_ears_review.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_requirements_ears_review.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_required_file_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-required-file"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.rules/requirements_ears_review_rule.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_requirements_ears_review.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .rules/requirements_ears_review_rule.md"
}

test_fails_when_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-model-phase"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
repo_analyse | codex | gpt-5.4
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_requirements_ears_review.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'requirements_ears_review' entry"
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
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_QUALITY_HELPER_FAIL=1 .commands/feature_requirements_ears_review.sh --feature_path "projects/p1/feature-a"
  )"
  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears.md"
  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears_review.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "quality gate command"
  assert_contains "$codex_prompt" "check_requirements_ears_review_quality.sh projects/p1/feature-a/requirements_ears_review.md"
}

test_runs_codex_and_commits_only_review_artifacts() {
  local repo_dir="$TMP_ROOT/repo-success-default"
  local capture_dir="$TMP_ROOT/capture-success-default"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local summary_before
  summary_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  echo "local-change" >>"$repo_dir/asdlc/README.md"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_requirements_ears_review.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears.md"
  assert_contains "$out" "Updated projects/p1/feature-a/requirements_ears_review.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears_review.md"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/requirements_ears_review_rule.md"
  assert_contains "$codex_prompt" "Read-only feature BR summary source: projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$codex_prompt" "Mutable requirements EARS target: projects/p1/feature-a/requirements_ears.md"
  assert_contains "$codex_prompt" "Mutable review ledger target: projects/p1/feature-a/requirements_ears_review.md"
  assert_contains "$codex_prompt" "Template file: .templates/requirements_ears_review_TEMPLATE.md"
  assert_contains "$codex_prompt" "Golden example file: .golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"
  assert_contains "$codex_prompt" "Here is the finding: <concise gap summary for the current finding>"
  assert_contains "$codex_prompt" "I would recommend: <exact recommended change for this finding>"
  assert_contains "$codex_prompt" "Should I add recommended changes? Please answer yes/no or provide your answer."

  local summary_after
  summary_after="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  assert_equal "$summary_before" "$summary_after"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears_review.md"
}

test_runs_with_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-success-override"
  local capture_dir="$TMP_ROOT/capture-success-override"
  local feature_path="projects/p1/custom-folder"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_feature_sources "$repo_dir" "$feature_path"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_REQUIREMENTS_FILE="$feature_path/requirements_ears.md" TARGET_REVIEW_FILE="$feature_path/requirements_ears_review.md" \
      .commands/feature_requirements_ears_review.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "Updated $feature_path/requirements_ears.md"
  assert_contains "$out" "Updated $feature_path/requirements_ears_review.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/requirements_ears_review.md"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Read-only feature BR summary source: $feature_path/feature_br_summary.md"
  assert_contains "$codex_prompt" "Mutable review ledger target: $feature_path/requirements_ears_review.md"
  assert_not_contains "$codex_prompt" "Mutable review ledger target: projects/p1/feature-a/requirements_ears_review.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_required_file_is_missing
test_fails_when_model_phase_missing
test_does_not_run_quality_helper_directly
test_runs_codex_and_commits_only_review_artifacts
test_runs_with_absolute_feature_path

echo "All requirements EARS review initializer tests passed."
