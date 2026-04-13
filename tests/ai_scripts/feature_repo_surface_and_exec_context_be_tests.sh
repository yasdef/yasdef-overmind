#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_repo_surface_and_exec_context.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/feature_repo_surface_and_exec_context_rule.md"
SURFACE_TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md"
SURFACE_GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"

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

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_repo_surface_and_exec_context.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/feature_repo_surface_and_exec_context_rule.md"
  cp "$SURFACE_TEMPLATE_SRC" "$repo_dir/asdlc/.templates/project_surface_struct_resp_map_be_TEMPLATE.md"
  cp "$SURFACE_GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_repo_surface_and_exec_context.sh"

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
feature_repo_surface_and_exec_context | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

write_quality_gate_stub() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  {
    echo "$1"
    echo "$2"
  } >"$capture_dir/helper_args.txt"
fi

if [[ "${TEST_QUALITY_HELPER_FAIL:-0}" == "1" ]]; then
  echo "backend repo surface quality gate failed in helper"
  exit 1
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
}

seed_project_definition() {
  local repo_dir="$1"
  local backend_repo_path="$2"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$backend_repo_path"
steps: []
EOF_DEF
}

seed_feature_sources() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements
- RQ-1: backend must expose risk score in response.
OUT

  cat >"$repo_dir/asdlc/$feature_path/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- delta_needed: true
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
surface_file="${TARGET_SURFACE_FILE:-projects/p1/feature-a/project_surface_struct_resp_map_backend.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$surface_file")"
cat >"$surface_file" <<'DOC'
# Backend Repo Surface Context

## 1. Document Meta
- repo_name: backend-repo
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  local backend_repo_path="$2"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_project_definition "$repo_dir" "$backend_repo_path"
  seed_feature_sources "$repo_dir"

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
  local repo_dir="$TMP_ROOT/repo-be-missing-arg"
  local backend_repo="$TMP_ROOT/backend-repo-missing-arg"
  mkdir -p "$repo_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_repo_surface_and_exec_context.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-be-staged-required"
  local backend_repo="$TMP_ROOT/backend-repo-staged-required"
  mkdir -p "$repo_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"

  cp "$repo_dir/asdlc/.commands/feature_repo_surface_and_exec_context.sh" "$repo_dir/feature_repo_surface_and_exec_context.sh"
  chmod +x "$repo_dir/feature_repo_surface_and_exec_context.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_repo_surface_and_exec_context.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-be-missing-model"
  local backend_repo="$TMP_ROOT/backend-repo-missing-model"
  mkdir -p "$repo_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
repo_analyse | codex | gpt-5.4
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'feature_repo_surface_and_exec_context' entry"
}

test_fails_when_no_ready_repo_exists() {
  local repo_dir="$TMP_ROOT/repo-be-no-ready-repo"
  local backend_repo="$TMP_ROOT/backend-repo-no-ready-repo"
  mkdir -p "$repo_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "deferred"
      path: "$backend_repo"
steps: []
EOF_DEF

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "No ready repository paths found for active classes"
  assert_contains "$out" "backend: state is 'deferred', not ready"
}

test_does_not_run_quality_helper_directly() {
  local repo_dir="$TMP_ROOT/repo-be-helper-model-owned"
  local capture_dir="$TMP_ROOT/capture-be-helper-model-owned"
  local backend_repo="$TMP_ROOT/backend-repo-helper-model-owned"
  mkdir -p "$repo_dir" "$capture_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"
  setup_codex_stub "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_QUALITY_HELPER_FAIL=1 \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "quality gate command"
  assert_contains "$codex_prompt" "check_feature_repo_surface_and_exec_context_be_quality.sh projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
}

test_runs_codex_and_commits_only_target_files() {
  local repo_dir="$TMP_ROOT/repo-be-success"
  local capture_dir="$TMP_ROOT/capture-be-success"
  local backend_repo="$TMP_ROOT/backend-repo-success"
  mkdir -p "$repo_dir" "$capture_dir" "$backend_repo/src/main"
  setup_git_workspace "$repo_dir" "$backend_repo"
  setup_codex_stub "$repo_dir"
  echo "local-change" >>"$repo_dir/asdlc/README.md"

  local requirements_before
  local delta_before
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  delta_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_file_not_exists "$repo_dir/asdlc/projects/p1/feature-a/repo_agent_guidance_backend.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  local backend_repo_resolved
  backend_repo_resolved="$(cd "$backend_repo" && pwd -P)"
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/feature_repo_surface_and_exec_context_rule.md"
  assert_contains "$codex_prompt" "Track-specific bindings for shared rule:"
  assert_contains "$codex_prompt" "Target track: backend"
  assert_contains "$codex_prompt" "Target repository class: backend"
  assert_contains "$codex_prompt" "Artifact meta project_classes value: backend"
  assert_contains "$codex_prompt" "Target repo surface map artifact: projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_contains "$codex_prompt" "- backend: $backend_repo_resolved"

  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$delta_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"

  assert_equal "Generate repo surface and execution context for backend" "$(git -C "$repo_dir/asdlc" log -1 --pretty=%s)"
  local committed_files
  committed_files="$(git -C "$repo_dir/asdlc" show --name-only --pretty='' HEAD)"
  assert_contains "$committed_files" "projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/requirements_ears.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/feature_contract_delta.md"
  assert_not_contains "$committed_files" "README.md"
}

test_skips_empty_commit_when_output_is_unchanged() {
  local repo_dir="$TMP_ROOT/repo-be-empty-commit"
  local capture_dir="$TMP_ROOT/capture-be-empty-commit"
  local backend_repo="$TMP_ROOT/backend-repo-empty-commit"
  mkdir -p "$repo_dir" "$capture_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  local commits_after_first
  commits_after_first="$(git -C "$repo_dir/asdlc" rev-list --count HEAD)"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  local commits_after_second
  commits_after_second="$(git -C "$repo_dir/asdlc" rev-list --count HEAD)"

  assert_equal "$commits_after_first" "$commits_after_second"
}

test_runs_with_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-be-absolute-feature-path"
  local capture_dir="$TMP_ROOT/capture-be-absolute-feature-path"
  local backend_repo="$TMP_ROOT/backend-repo-absolute-feature-path"
  local feature_path="projects/p1/custom-feature"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir" "$backend_repo"
  setup_git_workspace "$repo_dir" "$backend_repo"
  seed_feature_sources "$repo_dir" "$feature_path"
  setup_codex_stub "$repo_dir"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
    TARGET_SURFACE_FILE="$feature_path/project_surface_struct_resp_map_backend.md" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "Updated $feature_path/project_surface_struct_resp_map_backend.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_backend.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_model_phase_missing
test_fails_when_no_ready_repo_exists
test_does_not_run_quality_helper_directly
test_runs_codex_and_commits_only_target_files
test_skips_empty_commit_when_output_is_unchanged
test_runs_with_absolute_feature_path

echo "All backend repo-surface/execution-context initializer tests passed."
