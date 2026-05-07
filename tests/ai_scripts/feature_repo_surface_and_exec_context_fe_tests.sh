#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_repo_surface_and_exec_context.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/feature_repo_surface_and_exec_context_rule.md"
SURFACE_TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/project_surface_struct_resp_map_fe_TEMPLATE.md"
SURFACE_GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"

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
  cp "$SURFACE_TEMPLATE_SRC" "$repo_dir/asdlc/.templates/project_surface_struct_resp_map_fe_TEMPLATE.md"
  cp "$SURFACE_GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
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
  cat >"$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh" <<'OUT'
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
  echo "frontend/mobile repo surface quality gate failed in helper"
  exit 1
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
}

seed_project_definition() {
  local repo_dir="$1"
  local fe_repo_path="$2"
  local mobile_repo_path="$3"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - frontend
    - mobile
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    frontend:
      state: "ready"
      path: "$fe_repo_path"
    mobile:
      state: "ready"
      path: "$mobile_repo_path"
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
- RQ-1: client repos must render risk score with fallback behavior.
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
surface_file="${TARGET_SURFACE_FILE:-projects/p1/feature-a/project_surface_struct_resp_map_frontend.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$surface_file")"
cat >"$surface_file" <<'DOC'
# Client Repo Surface Context

## 1. Document Meta
- repo_name: client-repo
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  local fe_repo_path="$2"
  local mobile_repo_path="$3"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_project_definition "$repo_dir" "$fe_repo_path" "$mobile_repo_path"
  seed_feature_sources "$repo_dir"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-fe-missing-arg"
  local fe_repo="$TMP_ROOT/fe-repo-missing-arg"
  local mobile_repo="$TMP_ROOT/mobile-repo-missing-arg"
  mkdir -p "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"

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
  local repo_dir="$TMP_ROOT/repo-fe-staged-required"
  local fe_repo="$TMP_ROOT/fe-repo-staged-required"
  local mobile_repo="$TMP_ROOT/mobile-repo-staged-required"
  mkdir -p "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"

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
  local repo_dir="$TMP_ROOT/repo-fe-missing-model"
  local fe_repo="$TMP_ROOT/fe-repo-missing-model"
  local mobile_repo="$TMP_ROOT/mobile-repo-missing-model"
  mkdir -p "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
repo_analyse | codex | gpt-5.4
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'feature_repo_surface_and_exec_context' entry"
}

test_selects_frontend_by_class_name() {
  local repo_dir="$TMP_ROOT/repo-fe-frontend-success"
  local capture_dir="$TMP_ROOT/capture-fe-frontend-success"
  local fe_repo="$TMP_ROOT/fe-repo-frontend-success"
  local mobile_repo="$TMP_ROOT/mobile-repo-frontend-success"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo/src" "$mobile_repo/src"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
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
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" 2>&1
  )"

  assert_contains "$out" "Analysis targets available:"
  assert_contains "$out" "Select target to analyze now (number or class name):"
  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  assert_file_not_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  local fe_repo_resolved
  local mobile_repo_resolved
  fe_repo_resolved="$(cd "$fe_repo" && pwd -P)"
  mobile_repo_resolved="$(cd "$mobile_repo" && pwd -P)"
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/feature_repo_surface_and_exec_context_rule.md"
  assert_contains "$codex_prompt" "Track-specific bindings for shared rule:"
  assert_contains "$codex_prompt" "Target track: frontend"
  assert_contains "$codex_prompt" "Target repository class: frontend"
  assert_contains "$codex_prompt" "Artifact meta project_classes value: frontend"
  assert_contains "$codex_prompt" "Target repo surface map artifact: projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  assert_contains "$codex_prompt" "- frontend: $fe_repo_resolved"
  assert_not_contains "$codex_prompt" "- mobile: $mobile_repo_resolved"

  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$delta_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"
}

test_selects_mobile_by_number() {
  local repo_dir="$TMP_ROOT/repo-fe-mobile-success"
  local capture_dir="$TMP_ROOT/capture-fe-mobile-success"
  local fe_repo="$TMP_ROOT/fe-repo-mobile-success"
  local mobile_repo="$TMP_ROOT/mobile-repo-mobile-success"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo/src" "$mobile_repo/src"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_codex_stub "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_SURFACE_FILE="projects/p1/feature-a/project_surface_struct_resp_map_mobile.md" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"2" 2>&1
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"

  local codex_prompt
  local fe_repo_resolved
  local mobile_repo_resolved
  fe_repo_resolved="$(cd "$fe_repo" && pwd -P)"
  mobile_repo_resolved="$(cd "$mobile_repo" && pwd -P)"
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Target track: mobile"
  assert_contains "$codex_prompt" "Target repository class: mobile"
  assert_contains "$codex_prompt" "Artifact meta project_classes value: mobile"
  assert_contains "$codex_prompt" "Target repo surface map artifact: projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
  assert_contains "$codex_prompt" "- mobile: $mobile_repo_resolved"
  assert_not_contains "$codex_prompt" "- frontend: $fe_repo_resolved"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
}

test_does_not_run_quality_helper_directly() {
  local repo_dir="$TMP_ROOT/repo-fe-helper-model-owned"
  local capture_dir="$TMP_ROOT/capture-fe-helper-model-owned"
  local fe_repo="$TMP_ROOT/fe-repo-helper-model-owned"
  local mobile_repo="$TMP_ROOT/mobile-repo-helper-model-owned"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_codex_stub "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_QUALITY_HELPER_FAIL=1 \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" 2>&1
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "quality gate command"
  assert_contains "$codex_prompt" "check_feature_repo_surface_and_exec_context_fe_quality.sh projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
}

test_skips_empty_commit_when_output_is_unchanged() {
  local repo_dir="$TMP_ROOT/repo-fe-empty-commit"
  local capture_dir="$TMP_ROOT/capture-fe-empty-commit"
  local fe_repo="$TMP_ROOT/fe-repo-empty-commit"
  local mobile_repo="$TMP_ROOT/mobile-repo-empty-commit"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" >/dev/null
  )
  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" >/dev/null
  )
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
}

test_runs_with_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-fe-absolute-feature-path"
  local capture_dir="$TMP_ROOT/capture-fe-absolute-feature-path"
  local fe_repo="$TMP_ROOT/fe-repo-absolute-feature-path"
  local mobile_repo="$TMP_ROOT/mobile-repo-absolute-feature-path"
  local feature_path="projects/p1/custom-feature"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  seed_feature_sources "$repo_dir" "$feature_path"
  setup_codex_stub "$repo_dir"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_SURFACE_FILE="$feature_path/project_surface_struct_resp_map_mobile.md" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "$absolute_feature_path" <<<"mobile"
  )"

  assert_contains "$out" "Updated $feature_path/project_surface_struct_resp_map_mobile.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_mobile.md"
  assert_file_not_exists "$capture_dir/helper_args.txt"
}

test_prompt_references_rule_file() {
  local repo_dir="$TMP_ROOT/repo-fe-rule-ref"
  local capture_dir="$TMP_ROOT/capture-fe-rule-ref"
  local fe_repo="$TMP_ROOT/fe-repo-rule-ref"
  local mobile_repo="$TMP_ROOT/mobile-repo-rule-ref"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo" "$mobile_repo"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  seed_feature_sources "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" >/dev/null
  )

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "feature_repo_surface_and_exec_context_rule.md"
}

setup_git_workspace_type_a() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_feature_sources "$repo_dir"
}

seed_type_a_frontend_only_no_repo() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_id: "p1"
  project_classes:
    - frontend
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    frontend:
      state: "deferred"
      path: ""
steps: []
EOF_DEF
}

seed_type_a_mobile_only_no_repo() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'EOF_DEF'
meta_info:
  project_id: "p1"
  project_classes:
    - mobile
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    mobile:
      state: "deferred"
      path: ""
steps: []
EOF_DEF
}

seed_type_a_be_and_fe_mixed() {
  local repo_dir="$1"
  local backend_repo_path="$2"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$backend_repo_path"
    frontend:
      state: "deferred"
      path: ""
steps: []
EOF_DEF
}

seed_frontend_blueprint() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/asdlc/projects/p1"
  cat >"$repo_dir/asdlc/projects/p1/project_stack_blueprint_frontend.md" <<'OUT'
# Frontend Stack Blueprint

## Layer Conventions
- ui: pages under src/features/
- components: reusable under src/components/
- state: hooks under src/state/
OUT
}

seed_mobile_blueprint() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/asdlc/projects/p1"
  cat >"$repo_dir/asdlc/projects/p1/project_stack_blueprint_mobile.md" <<'OUT'
# Mobile Stack Blueprint

## Layer Conventions
- screens: screen components under src/screens/
- viewmodels: view models under src/viewmodels/
OUT
}

seed_backend_blueprint_fe() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/asdlc/projects/p1"
  cat >"$repo_dir/asdlc/projects/p1/project_stack_blueprint_backend.md" <<'OUT'
# Backend Stack Blueprint

## Layer Conventions
- api: controllers under src/api/
OUT
}

setup_codex_stub_for_frontend() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
surface_file="${TARGET_SURFACE_FILE:-projects/p1/feature-a/project_surface_struct_resp_map_frontend.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$surface_file")"
cat >"$surface_file" <<'DOC'
# Client Repo Surface Context

## 1. Document Meta
- repo_name: client-repo
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_codex_stub_for_mobile() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
surface_file="${TARGET_SURFACE_FILE:-projects/p1/feature-a/project_surface_struct_resp_map_mobile.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$surface_file")"
cat >"$surface_file" <<'DOC'
# Client Repo Surface Context

## 1. Document Meta
- repo_name: mobile-repo
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

test_type_a_frontend_blueprint_only_invokes_model() {
  local repo_dir="$TMP_ROOT/repo-fe-type-a-fe-blueprint"
  local capture_dir="$TMP_ROOT/capture-fe-type-a-fe-blueprint"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace_type_a "$repo_dir"
  seed_type_a_frontend_only_no_repo "$repo_dir"
  seed_frontend_blueprint "$repo_dir"
  setup_codex_stub_for_frontend "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "planned structural evidence"
  assert_contains "$codex_prompt" "project_stack_blueprint_frontend.md"
}

test_type_a_mobile_blueprint_only_invokes_model() {
  local repo_dir="$TMP_ROOT/repo-fe-type-a-mobile-blueprint"
  local capture_dir="$TMP_ROOT/capture-fe-type-a-mobile-blueprint"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace_type_a "$repo_dir"
  seed_type_a_mobile_only_no_repo "$repo_dir"
  seed_mobile_blueprint "$repo_dir"
  setup_codex_stub_for_mobile "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
    TARGET_SURFACE_FILE="projects/p1/feature-a/project_surface_struct_resp_map_mobile.md" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_mobile.md"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "planned structural evidence"
  assert_contains "$codex_prompt" "project_stack_blueprint_mobile.md"
}

test_type_a_mixed_be_repo_fe_blueprint() {
  local repo_dir="$TMP_ROOT/repo-fe-type-a-mixed"
  local capture_dir_be="$TMP_ROOT/capture-fe-type-a-mixed-be"
  local capture_dir_fe="$TMP_ROOT/capture-fe-type-a-mixed-fe"
  local backend_repo="$TMP_ROOT/backend-repo-type-a-mixed"
  mkdir -p "$repo_dir" "$capture_dir_be" "$capture_dir_fe" "$backend_repo/src"
  setup_git_workspace_type_a "$repo_dir"
  seed_type_a_be_and_fe_mixed "$repo_dir" "$backend_repo"
  seed_frontend_blueprint "$repo_dir"
  seed_backend_blueprint_fe "$repo_dir"

  local backend_repo_resolved
  backend_repo_resolved="$(cd "$backend_repo" && pwd -P)"

  local be_template_src="$SOURCE_ROOT/overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md"
  local be_golden_src="$SOURCE_ROOT/overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  local be_helper_src="$SOURCE_ROOT/overmind/scripts/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"

  cp "$be_template_src" "$repo_dir/asdlc/.templates/project_surface_struct_resp_map_be_TEMPLATE.md"
  cp "$be_golden_src" "$repo_dir/asdlc/.golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  mkdir -p "$repo_dir/asdlc/.helper"
  cat >"$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh" <<'OUT'
#!/usr/bin/env bash
echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"

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
# Surface Map

## 1. Document Meta
- repo_name: test-repo
DOC
OUT
  chmod +x "$repo_dir/bin/codex"

  local out_be=""
  out_be="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir_be" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"backend"
  )"

  assert_contains "$out_be" "Updated projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  local prompt_be
  prompt_be="$(cat "$capture_dir_be/codex_prompt.txt")"
  assert_contains "$prompt_be" "- backend: $backend_repo_resolved"
  assert_contains "$prompt_be" "planned structural evidence"
  assert_contains "$prompt_be" "project_stack_blueprint_backend.md"

  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail
capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
surface_file="${TARGET_SURFACE_FILE:-projects/p1/feature-a/project_surface_struct_resp_map_frontend.md}"
printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"
mkdir -p "$(dirname "$surface_file")"
cat >"$surface_file" <<'DOC'
# Surface Map

## 1. Document Meta
- repo_name: test-repo
DOC
OUT

  local out_fe=""
  out_fe="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir_fe" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend"
  )"

  assert_contains "$out_fe" "Updated projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
  local prompt_fe
  prompt_fe="$(cat "$capture_dir_fe/codex_prompt.txt")"
  assert_contains "$prompt_fe" "planned structural evidence"
  assert_contains "$prompt_fe" "project_stack_blueprint_frontend.md"
  assert_contains "$prompt_fe" "(no ready repository"
  assert_not_contains "$prompt_fe" "- frontend: $backend_repo_resolved"
}

test_type_a_fe_prompt_assertions() {
  local repo_dir="$TMP_ROOT/repo-fe-type-a-fe-prompt"
  local capture_dir="$TMP_ROOT/capture-fe-type-a-fe-prompt"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace_type_a "$repo_dir"
  seed_type_a_frontend_only_no_repo "$repo_dir"
  seed_frontend_blueprint "$repo_dir"
  setup_codex_stub_for_frontend "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" >/dev/null
  )

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "planned structural evidence"
  assert_contains "$codex_prompt" "project_stack_blueprint_frontend.md"
}

test_type_b_fe_does_not_bind_stack_blueprint() {
  local repo_dir="$TMP_ROOT/repo-fe-type-b-no-blueprint"
  local capture_dir="$TMP_ROOT/capture-fe-type-b-no-blueprint"
  local fe_repo="$TMP_ROOT/fe-repo-type-b-no-blueprint"
  local mobile_repo="$TMP_ROOT/mobile-repo-type-b-no-blueprint"
  mkdir -p "$repo_dir" "$capture_dir" "$fe_repo/src" "$mobile_repo/src"
  setup_git_workspace "$repo_dir" "$fe_repo" "$mobile_repo"
  seed_frontend_blueprint "$repo_dir"
  seed_mobile_blueprint "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      .commands/feature_repo_surface_and_exec_context.sh --feature_path "projects/p1/feature-a" <<<"frontend" >/dev/null
  )

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_not_contains "$codex_prompt" "planned structural evidence"
  assert_not_contains "$codex_prompt" "project_stack_blueprint_frontend.md"
  assert_not_contains "$codex_prompt" "blueprint fallback"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_model_phase_missing
test_selects_frontend_by_class_name
test_selects_mobile_by_number
test_does_not_run_quality_helper_directly
test_skips_empty_commit_when_output_is_unchanged
test_runs_with_absolute_feature_path
test_prompt_references_rule_file
test_type_a_frontend_blueprint_only_invokes_model
test_type_a_mobile_blueprint_only_invokes_model
test_type_a_mixed_be_repo_fe_blueprint
test_type_a_fe_prompt_assertions
test_type_b_fe_does_not_bind_stack_blueprint

echo "All frontend/mobile repo-surface/execution-context initializer tests passed."
