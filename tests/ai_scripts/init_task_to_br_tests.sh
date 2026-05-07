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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "Assertion failed: expected output NOT to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
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
    printf "1\nepic_story_input.md\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "Target artifact: projects/p1/feature-a/feature_br_summary.md"
}

test_file_path_option_preserves_existing_behaviour() {
  local repo_dir="$TMP_ROOT/repo-file-path-opt"
  local capture_dir="$TMP_ROOT/capture-file-path-opt"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc"
    printf "1\nepic_story_input.md\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local user_input_content
  user_input_content="$(cat "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md")"
  local prompt_content
  prompt_content="$(cat "$capture_dir/codex_prompt.txt")"

  assert_not_contains "$user_input_content" "jira_ticket"
  assert_not_contains "$prompt_content" "Jira MCP fetch instruction"
}

test_jira_mcp_option_with_matching_source() {
  local repo_dir="$TMP_ROOT/repo-jira-match"
  local capture_dir="$TMP_ROOT/capture-jira-match"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/external_sources.yaml" <<'OUT'
sources:
  - name: my-jira-mcp
    type: jira
    description: Test Jira MCP source
OUT

  (
    cd "$repo_dir/asdlc"
    printf "2\nCRP-122\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local user_input_content
  user_input_content="$(cat "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md")"
  local prompt_content
  prompt_content="$(cat "$capture_dir/codex_prompt.txt")"

  assert_contains "$user_input_content" "jira_ticket: CRP-122"
  assert_contains "$user_input_content" "epic_story_source_file: jira:CRP-122"
  assert_contains "$prompt_content" "my-jira-mcp"
  assert_contains "$prompt_content" "Jira MCP fetch instruction"
}

test_jira_mcp_option_with_no_matching_source() {
  local repo_dir="$TMP_ROOT/repo-jira-empty"
  local capture_dir="$TMP_ROOT/capture-jira-empty"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/external_sources.yaml" <<'OUT'
sources:
  - name: some-kb
    type: stack_knowledge_base
    description: Non-Jira source
OUT

  (
    cd "$repo_dir/asdlc"
    printf "2\nT-1\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local prompt_content
  prompt_content="$(cat "$capture_dir/codex_prompt.txt")"

  assert_contains "$prompt_content" "Jira MCP fetch instruction"
  assert_contains "$prompt_content" "(none configured)"
  assert_contains "$prompt_content" "ask the user what to do"
}

test_invalid_choice_loops_then_valid_proceeds() {
  local repo_dir="$TMP_ROOT/repo-invalid-choice"
  local capture_dir="$TMP_ROOT/capture-invalid-choice"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local out
  out="$(
    cd "$repo_dir/asdlc"
    printf "invalid\n0\n1\nepic_story_input.md\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md"
}

test_empty_ticket_number_rejected() {
  local repo_dir="$TMP_ROOT/repo-empty-ticket"
  local capture_dir="$TMP_ROOT/capture-empty-ticket"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc"
    printf "2\n\n\nCRP-122\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local user_input_content
  user_input_content="$(cat "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md")"
  local prompt_content
  prompt_content="$(cat "$capture_dir/codex_prompt.txt")"

  assert_contains "$user_input_content" "jira_ticket: CRP-122"
  assert_contains "$prompt_content" "jira:CRP-122"
}

test_jira_source_br_output_has_section16_with_entries() {
  local repo_dir="$TMP_ROOT/repo-section16-entries"
  local capture_dir="$TMP_ROOT/capture-section16-entries"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/external_sources.yaml" <<'OUT'
sources:
  - name: my-jira-mcp
    type: jira
    description: Test Jira MCP source
OUT

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
- source_type: jira:CRP-999
- last_updated: 2026-04-06
- ready_to_ears: false

## 16. Linked Artifacts

- id: LAR-001
  title: Domain Model Diagram
  type: diagram
  locator: https://confluence.example.com/domain-model
- id: LAR-002
  title: Payments API Spec
  type: api_spec
  locator: https://confluence.example.com/api-spec
DOC
OUT
  chmod +x "$repo_dir/bin/codex"

  (
    cd "$repo_dir/asdlc"
    printf "2\nCRP-999\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local br_content
  br_content="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  assert_contains "$br_content" "## 16. Linked Artifacts"
  assert_contains "$br_content" "LAR-001"
  assert_contains "$br_content" "LAR-002"
}

test_jira_source_br_output_has_section16_empty_when_no_artifacts() {
  local repo_dir="$TMP_ROOT/repo-section16-empty"
  local capture_dir="$TMP_ROOT/capture-section16-empty"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/external_sources.yaml" <<'OUT'
sources:
  - name: my-jira-mcp
    type: jira
    description: Test Jira MCP source
OUT

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
- source_type: jira:CRP-999
- last_updated: 2026-04-06
- ready_to_ears: false

## 16. Linked Artifacts

DOC
OUT
  chmod +x "$repo_dir/bin/codex"

  (
    cd "$repo_dir/asdlc"
    printf "2\nCRP-999\n" | \
      PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_task_to_br.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local br_content
  br_content="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  assert_contains "$br_content" "## 16. Linked Artifacts"
  assert_not_contains "$br_content" "LAR-"
}

test_requires_feature_path_argument
test_requires_staged_location
test_fails_when_feature_summary_missing
test_updates_feature_with_user_input
test_file_path_option_preserves_existing_behaviour
test_jira_mcp_option_with_matching_source
test_jira_mcp_option_with_no_matching_source
test_invalid_choice_loops_then_valid_proceeds
test_empty_ticket_number_rejected
test_jira_source_br_output_has_section16_with_entries
test_jira_source_br_output_has_section16_empty_when_no_artifacts

echo "All task-to-BR initializer tests passed."
