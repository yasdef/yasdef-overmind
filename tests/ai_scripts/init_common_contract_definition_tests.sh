#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/init_common_contract_definition.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/common_contract_definition_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/common_contract_definition_TEMPLATE.md"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md"

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

setup_repo_layout() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/overmind/scripts"
  cp "$SCRIPT_SRC" "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  chmod +x "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
}

setup_staged_workspace() {
  local asdlc_root="$1"
  mkdir -p "$asdlc_root/.commands" "$asdlc_root/.rules" "$asdlc_root/.templates" "$asdlc_root/.golden_examples" "$asdlc_root/.setup" "$asdlc_root/.helper" "$asdlc_root/projects"
  cp "$SCRIPT_SRC" "$asdlc_root/.commands/init_common_contract_definition.sh"
  cp "$RULE_SRC" "$asdlc_root/.rules/common_contract_definition_rule.md"
  cp "$TEMPLATE_SRC" "$asdlc_root/.templates/common_contract_definition_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$asdlc_root/.golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md"
  chmod +x "$asdlc_root/.commands/init_common_contract_definition.sh"

  cat >"$asdlc_root/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "staged command test"
projects:
OUT

  (
    cd "$asdlc_root"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    git add asdlc_metadata.yaml .commands/init_common_contract_definition.sh .rules/common_contract_definition_rule.md .templates/common_contract_definition_TEMPLATE.md .golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md
    git commit -qm "seed staged workspace"
  )
}

setup_staged_models_file() {
  local asdlc_root="$1"
  cat >"$asdlc_root/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
common_contract_definition | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

write_staged_quality_gate_stub() {
  local asdlc_root="$1"
  cat >"$asdlc_root/.helper/check_common_contract_definition_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

echo "quality gate passed"
OUT
  chmod +x "$asdlc_root/.helper/check_common_contract_definition_quality.sh"
}

setup_codex_stub() {
  local root_dir="$1"
  mkdir -p "$root_dir/bin"
  cat >"$root_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_COMMON_CONTRACT_FILE:?TARGET_COMMON_CONTRACT_FILE must be set}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Common Contract Definition

## 1. Document Meta
- project_id: sample-project
- project_path: /tmp/asdlc/projects/sample-project
- source_repo_count: 1
- source_repositories: backend
- last_updated: 2026-04-04
- confidence_level: high

## 2. Source Repository Evidence
### Repository: backend
- class: backend
- repo_path: /tmp/repos/backend
- contract_evidence_summary: Reviewed backend request/response and event contracts.
- key_surfaces_reviewed: /api/v1/payments, payment-created topic
- notes: Backend provides canonical contract payload definitions.

## 3. Common Contract Baseline
### Contract: payment-status-model
- shared_contract_type: domain_state_contract
- canonical_definition: Shared payment statuses and allowed transitions.
- participating_repositories: backend
- source_of_truth: backend domain model
- versioning_strategy: additive only
- owner: backend API team
- notes: downstream consumers align to this semantic model.

## 4. Reconciliation Decisions
- decision_1: backend contract definitions are canonical for shared payment status semantics.

## 5. Known Risks / Uncertainties
- uncertainty_1: formal schema governance for breaking changes is not yet documented.
DOC
OUT
  chmod +x "$root_dir/bin/codex"
}

write_project_definition() {
  local project_dir="$1"
  local backend_state="${2:-ready}"
  local backend_path="${3:-}"
  local frontend_state="${4:-deferred}"
  local frontend_path="${5:-}"
  local project_type_code="${6:-B}"
  local project_type_label="Existing project with partial context"

  if [[ "$project_type_code" == "A" ]]; then
    project_type_label="New project"
  elif [[ "$project_type_code" == "C" ]]; then
    project_type_label="Existing project with code-first context"
  fi

  cat >"$project_dir/init_progress_definition.yaml" <<EOF2
meta_info:
  project_id: "sample-project"
  project_classes:
    - backend
    - frontend
  project_type_code: "$project_type_code"
  project_type_label: "$project_type_label"
  class_repo_paths:
    backend:
      state: "$backend_state"
      path: "$backend_path"
    frontend:
      state: "$frontend_state"
      path: "$frontend_path"

steps: []
EOF2
}

test_fails_fast_for_project_type_a() {
  local workspace="$TMP_ROOT/workspace-project-type-a"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"
  write_project_definition "$project_dir" "deferred" "" "deferred" "" "A"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "project type A is not supported yet: MCP extraction for common contract definition is unavailable"
}

test_fails_fast_when_run_from_repo_path() {
  local repo_dir="$TMP_ROOT/repo-fail-fast"
  mkdir -p "$repo_dir"
  setup_repo_layout "$repo_dir"

  local out=""
  local status=0
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/init_common_contract_definition.sh --path "$TMP_ROOT/any" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "init asdlc repo first, run this script only from asldc/.commands"
}

test_fails_when_path_argument_is_missing() {
  local workspace="$TMP_ROOT/workspace-missing-path"
  local asdlc_root="$workspace/asdlc"
  mkdir -p "$workspace"
  setup_staged_workspace "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --path"
}

test_fails_when_path_is_outside_asdlc_projects() {
  local workspace="$TMP_ROOT/workspace-path-outside"
  local asdlc_root="$workspace/asdlc"
  local outside_project="$TMP_ROOT/not-in-asdlc-projects"
  mkdir -p "$outside_project"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$outside_project" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"
}

test_fails_when_definition_file_is_missing() {
  local workspace="$TMP_ROOT/workspace-missing-definition"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "project-level folder containing init_progress_definition.yaml"
}

test_fails_when_no_usable_repository_paths_exist() {
  local workspace="$TMP_ROOT/workspace-no-usable-repos"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"
  write_project_definition "$project_dir" "deferred" "" "deferred" ""

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "No usable repository paths found in meta_info.class_repo_paths"
}

test_fails_when_ready_repo_path_is_invalid() {
  local workspace="$TMP_ROOT/workspace-invalid-ready-repo-path"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  local missing_repo="$TMP_ROOT/missing-ready-repo"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"
  write_project_definition "$project_dir" "ready" "$missing_repo" "deferred" ""

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "does not exist or is not a directory"
}

test_fails_when_path_points_to_projects_parent() {
  local workspace="$TMP_ROOT/workspace-projects-parent"
  local asdlc_root="$workspace/asdlc"
  local projects_root="$asdlc_root/projects"
  mkdir -p "$projects_root"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$projects_root" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"
}

test_fails_when_path_points_to_project_subfolder() {
  local workspace="$TMP_ROOT/workspace-project-subfolder"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  local subfolder_path="$project_dir/docs"
  mkdir -p "$subfolder_path"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$subfolder_path" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"
}

test_fails_when_path_points_to_other_asdlc_workspace_project() {
  local workspace_a="$TMP_ROOT/workspace-path-other-asdlc-a"
  local workspace_b="$TMP_ROOT/workspace-path-other-asdlc-b"
  local asdlc_root_a="$workspace_a/asdlc"
  local asdlc_root_b="$workspace_b/asdlc"
  local project_dir_b="$asdlc_root_b/projects/sample-project"
  mkdir -p "$project_dir_b"
  setup_staged_workspace "$asdlc_root_a"
  setup_staged_models_file "$asdlc_root_a"
  write_staged_quality_gate_stub "$asdlc_root_a"
  setup_staged_workspace "$asdlc_root_b"
  setup_staged_models_file "$asdlc_root_b"
  write_staged_quality_gate_stub "$asdlc_root_b"
  write_project_definition "$project_dir_b" "ready" "$TMP_ROOT" "deferred" ""

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root_a/.commands/init_common_contract_definition.sh" --path "$project_dir_b" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project path must resolve to asdlc/projects/<project-id>"
}

test_runs_codex_with_project_scoped_output_and_repo_context() {
  local workspace="$TMP_ROOT/workspace-success"
  local asdlc_root="$workspace/asdlc"
  local project_dir="$asdlc_root/projects/sample-project"
  local capture_dir="$TMP_ROOT/capture-success"
  local backend_repo="$TMP_ROOT/backend-repo"
  local frontend_repo="$TMP_ROOT/frontend-repo"
  mkdir -p "$project_dir" "$capture_dir" "$backend_repo" "$frontend_repo"
  setup_staged_workspace "$asdlc_root"
  setup_staged_models_file "$asdlc_root"
  write_staged_quality_gate_stub "$asdlc_root"
  setup_codex_stub "$asdlc_root"
  write_project_definition "$project_dir" "ready" "$backend_repo" "ready" "$frontend_repo"
  git -C "$asdlc_root" checkout -q -b "feature/common-contract-auto-commit"

  local branch_before=""
  local branch_after=""
  local committed_paths=""
  branch_before="$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"

  local out=""
  out="$({
    cd "$TMP_ROOT" &&
    PATH="$asdlc_root/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
      TARGET_COMMON_CONTRACT_FILE="$project_dir/common_contract_definition.md" \
      "$asdlc_root/.commands/init_common_contract_definition.sh" --path "$project_dir"
  })"

  assert_contains "$out" "Updated $project_dir/common_contract_definition.md"
  assert_contains "$out" "Committed $project_dir/common_contract_definition.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_file_exists "$project_dir/common_contract_definition.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
  assert_equal "Update common contract definition for sample-project" "$(git -C "$asdlc_root" log -1 --pretty=%s)"
  committed_paths="$(git -C "$asdlc_root" show --pretty='' --name-only HEAD)"
  assert_contains "$committed_paths" "projects/sample-project/common_contract_definition.md"
  branch_after="$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"
  assert_equal "$branch_before" "$branch_after"

  local codex_args
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Rule file: .rules/common_contract_definition_rule.md"
  assert_contains "$codex_prompt" "Project definition file: $project_dir/init_progress_definition.yaml"
  assert_contains "$codex_prompt" "Target common contract definition artifact: $project_dir/common_contract_definition.md"
  assert_contains "$codex_prompt" "Quality gate helper: .helper/check_common_contract_definition_quality.sh"
  assert_contains "$codex_prompt" "Template file: .templates/common_contract_definition_TEMPLATE.md"
  assert_contains "$codex_prompt" "Golden example file: .golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md"
  assert_contains "$codex_prompt" "- backend: $backend_repo"
  assert_contains "$codex_prompt" "- frontend: $frontend_repo"
  assert_contains "$codex_prompt" "Repository root: $asdlc_root"
}

test_fails_fast_when_run_from_repo_path
test_fails_when_path_argument_is_missing
test_fails_when_path_is_outside_asdlc_projects
test_fails_when_definition_file_is_missing
test_fails_when_no_usable_repository_paths_exist
test_fails_fast_for_project_type_a
test_fails_when_ready_repo_path_is_invalid
test_fails_when_path_points_to_projects_parent
test_fails_when_path_points_to_project_subfolder
test_fails_when_path_points_to_other_asdlc_workspace_project
test_runs_codex_with_project_scoped_output_and_repo_context

echo "All common contract definition initializer tests passed."
