#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
CLASS_REPO_PATHS_LIB_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/class_repo_paths.sh"
RULE_FILE_SRC="$SOURCE_ROOT/overmind/rules/project_contract_reconciliation_rule.md"
QUALITY_GATE_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_common_contract_definition_quality.sh"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
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
  if [[ -e "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

setup_staged_workspace() {
  local asdlc_root="$1"

  mkdir -p "$asdlc_root/.commands" "$asdlc_root/.setup" "$asdlc_root/.rules" "$asdlc_root/.helper" "$asdlc_root/common_libs" "$asdlc_root/projects"
  cp "$SCRIPT_SRC" "$asdlc_root/.commands/project_contract_reconciliation.sh"
  cp "$CLASS_REPO_PATHS_LIB_SRC" "$asdlc_root/common_libs/class_repo_paths.sh"
  cp "$RULE_FILE_SRC" "$asdlc_root/.rules/project_contract_reconciliation_rule.md"
  cp "$QUALITY_GATE_HELPER_SRC" "$asdlc_root/.helper/check_common_contract_definition_quality.sh"
  chmod +x "$asdlc_root/.commands/project_contract_reconciliation.sh" "$asdlc_root/.helper/check_common_contract_definition_quality.sh"

  cat >"$asdlc_root/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "staged command test"
projects:
OUT

  cat >"$asdlc_root/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
project_contract_reconciliation | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
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

if [[ -n "${MUTATE_PROJECT_DEFINITION_PATH:-}" ]]; then
  echo "mutated" >>"$MUTATE_PROJECT_DEFINITION_PATH"
fi

cat >"$target_file" <<'DOC'
# Common Contract Definition

## 1. Document Meta
- project_id: p1
- project_path: projects/p1
- source_repo_count: 1
- source_repositories: backend
- last_updated: 2026-06-22
- confidence_level: high

## 2. Source Repository Evidence
### Repository: backend
- class: backend
- repo_path: /repo/backend
- contract_evidence_summary: REST API serving order resources
- key_surfaces_reviewed: GET /orders
- notes: none

## 3. Common Contract Baseline
### Contract: GET /orders
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: backend
- consumer_repositories: frontend
- contract_surface: GET /orders
- contract_status: single_source
- source_of_truth: backend
- canonical_shape: { id, status }
- shared_types: none
- trust_boundary: internal
- compatibility_rule: additive only
- planning_implication: none
- notes: none

## 4. Reconciliation Decisions
- decision_1: approved_correction backend API status enum now includes archived

## 5. Known Risks / Uncertainties
- uncertainty_1: none

## 6. Common Planning Signals
- prep_1: none
DOC
OUT
  chmod +x "$root_dir/bin/codex"
}

setup_git_repo() {
  local repo_root="$1"

  mkdir -p "$repo_root"
  git -C "$repo_root" init >/dev/null 2>&1
  git -C "$repo_root" config user.name "Test User"
  git -C "$repo_root" config user.email "test@example.com"
  echo "seed" >"$repo_root/README.md"
  git -C "$repo_root" add -A
  git -C "$repo_root" commit -m "Initial commit" >/dev/null 2>&1
}

write_project_definition() {
  local project_dir="$1"
  local backend_repo="$2"
  local frontend_state="${4:-deferred}"

  cat >"$project_dir/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  project_type_code: "B"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$backend_repo"
    frontend:
      state: "$frontend_state"

steps: []
EOF_DEF
}

write_project_definition_two_ready() {
  local project_dir="$1"
  local backend_repo="$2"
  local frontend_repo="$3"

  cat >"$project_dir/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  class_repo_paths:
    backend:
      state: "ready"
      path: "$backend_repo"
    frontend:
      state: "ready"
      path: "$frontend_repo"

steps: []
EOF_DEF
}

write_common_contract() {
  local project_dir="$1"

  cat >"$project_dir/common_contract_definition.md" <<'OUT'
# Common Contract Definition

## Current Documented Contract
- status_enum: active, disabled
OUT
}

setup_project_git() {
  local project_dir="$1"

  git -C "$project_dir" init >/dev/null 2>&1
  git -C "$project_dir" config user.name "Test User"
  git -C "$project_dir" config user.email "test@example.com"
  git -C "$project_dir" add -A
  git -C "$project_dir" commit -m "Seed project contract" >/dev/null 2>&1
}

test_fails_fast_when_run_from_repo_path() {
  local repo_dir="$TMP_ROOT/repo-fail-fast"
  mkdir -p "$repo_dir/overmind/scripts/project_mgmt"
  cp "$SCRIPT_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"

  local out=""
  local status=0
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/project_mgmt/project_contract_reconciliation.sh --path "$TMP_ROOT/any" --class backend 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path: <asdlc>/.commands/project_contract_reconciliation.sh"
}

test_fails_when_path_argument_is_missing() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-path"
  setup_staged_workspace "$asdlc_root"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/project_contract_reconciliation.sh" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --path"
}

test_fails_when_target_class_not_ready() {
  local asdlc_root="$TMP_ROOT/asdlc-not-ready"
  local project_dir="$asdlc_root/projects/p1"
  local backend_repo="$TMP_ROOT/not-ready-backend"
  local frontend_repo="$TMP_ROOT/not-ready-frontend"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition "$project_dir" "$backend_repo" "$frontend_repo" "deferred"
  perl -0pi -e 's/state: "ready"/state: "deferred"/' "$project_dir/init_progress_definition.yaml"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Target class 'backend' is not ready (state: 'deferred'); cannot reconcile."
}

test_fails_when_class_argument_missing() {
  local asdlc_root="$TMP_ROOT/asdlc-no-class"
  local project_dir="$asdlc_root/projects/p1"
  local backend_repo="$TMP_ROOT/no-class-backend"
  local frontend_repo="$TMP_ROOT/no-class-frontend"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition "$project_dir" "$backend_repo" "$frontend_repo" "deferred"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --class"
}

test_fails_when_rule_file_missing() {
  local asdlc_root="$TMP_ROOT/asdlc-no-rule"
  local project_dir="$asdlc_root/projects/p1"
  local backend_repo="$TMP_ROOT/no-rule-backend"
  local frontend_repo="$TMP_ROOT/no-rule-frontend"
  mkdir -p "$project_dir"
  setup_staged_workspace "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition "$project_dir" "$backend_repo" "$frontend_repo" "deferred"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"
  rm -f "$asdlc_root/.rules/project_contract_reconciliation_rule.md"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .rules/project_contract_reconciliation_rule.md"
}

test_runs_codex_with_contract_and_ready_repo_context_and_writes() {
  local asdlc_root="$TMP_ROOT/asdlc-success"
  local project_dir="$asdlc_root/projects/p1"
  local capture_dir="$TMP_ROOT/capture-success"
  local backend_repo="$TMP_ROOT/success-backend"
  local frontend_repo="$TMP_ROOT/success-frontend"
  mkdir -p "$project_dir" "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  setup_codex_stub "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition "$project_dir" "$backend_repo" "$frontend_repo" "deferred"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    PATH="$asdlc_root/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_COMMON_CONTRACT_FILE="$project_dir/common_contract_definition.md" \
      "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend
  )"

  assert_contains "$out" "Updated projects/p1/common_contract_definition.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" 'When contract reconciliation is fully complete, end your final response with this exact last line: "Contract reconciliation phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase"'
  assert_contains "$prompt" "Current common contract definition: projects/p1/common_contract_definition.md"
  assert_contains "$prompt" "- backend: $backend_repo"
  assert_not_contains "$prompt" "- frontend: $frontend_repo"
  assert_contains "$prompt" "Read and follow .rules/project_contract_reconciliation_rule.md fully before editing."
  assert_contains "$prompt" "Treat .rules/project_contract_reconciliation_rule.md as authoritative"
  assert_contains "$prompt" "Rule file: .rules/project_contract_reconciliation_rule.md"
  assert_contains "$prompt" "Quality gate command: .helper/check_common_contract_definition_quality.sh"
  assert_contains "$prompt" "run the quality gate command and make it pass"
  assert_contains "$prompt" "Out-of-scope classes (do not challenge their contract surface):"
  assert_contains "$prompt" "- frontend (deferred)"

  # The shell prompt stays thin; behavior (scope, read-only inputs, write-back,
  # and the quality-gate repair loop) lives in the rule file.
  local rule=""
  rule="$(cat "$asdlc_root/.rules/project_contract_reconciliation_rule.md")"
  assert_contains "$rule" "reconcile only the role played by an in-scope class, judged against that class's repository"
  assert_contains "$rule" "Treat any contract surface owned or produced by an out-of-scope class as read-only"
  assert_contains "$rule" "reconcile consumer drift"
  assert_contains "$rule" "Write back only operator-approved corrections"
  assert_contains "$rule" "Do not modify \`init_progress_definition.yaml\`"
  assert_contains "$rule" "Exit 1 means content problems"
  assert_contains "$rule" "Exit 2 means the helper itself failed"
  assert_not_contains "$prompt" "Write back only operator-approved corrections"
  assert_not_contains "$prompt" "reconcile only the role played by an in-scope class"

  assert_contains "$(cat "$project_dir/common_contract_definition.md")" "approved_correction"
  # The reconciliation script writes the contract but does not commit; the orchestrator commits the unit.
  assert_equal "Seed project contract" "$(git -C "$project_dir" log -1 --pretty=%s)"
}

test_blocks_model_mutating_project_definition() {
  local asdlc_root="$TMP_ROOT/asdlc-mutates-definition"
  local project_dir="$asdlc_root/projects/p1"
  local capture_dir="$TMP_ROOT/capture-mutates-definition"
  local backend_repo="$TMP_ROOT/mutates-definition-backend"
  local frontend_repo="$TMP_ROOT/mutates-definition-frontend"
  mkdir -p "$project_dir" "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  setup_codex_stub "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition "$project_dir" "$backend_repo" "$frontend_repo" "deferred"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  local out=""
  local status=0
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    PATH="$asdlc_root/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_COMMON_CONTRACT_FILE="$project_dir/common_contract_definition.md" \
      MUTATE_PROJECT_DEFINITION_PATH="$project_dir/init_progress_definition.yaml" \
      "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Contract reconciliation must not modify projects/p1/init_progress_definition.yaml"
  assert_equal "Seed project contract" "$(git -C "$project_dir" log -1 --pretty=%s)"
}

test_reconciles_multiple_target_classes_in_one_session() {
  local asdlc_root="$TMP_ROOT/asdlc-multi"
  local project_dir="$asdlc_root/projects/p1"
  local capture_dir="$TMP_ROOT/capture-multi"
  local backend_repo="$TMP_ROOT/multi-backend"
  local frontend_repo="$TMP_ROOT/multi-frontend"
  mkdir -p "$project_dir" "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  setup_codex_stub "$asdlc_root"
  setup_git_repo "$backend_repo"
  setup_git_repo "$frontend_repo"
  write_project_definition_two_ready "$project_dir" "$backend_repo" "$frontend_repo"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  out="$(
    cd "$TMP_ROOT" &&
    PATH="$asdlc_root/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_COMMON_CONTRACT_FILE="$project_dir/common_contract_definition.md" \
      "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend --class frontend
  )"

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "Unique repositories to inspect (scan each path once):"
  assert_contains "$prompt" "In-scope class-to-repository mappings:"
  assert_contains "$prompt" "- backend: $backend_repo"
  assert_contains "$prompt" "- frontend: $frontend_repo"
  assert_contains "$prompt" $'Out-of-scope classes (do not challenge their contract surface):\n- none'
}

test_preserves_class_context_when_target_classes_share_repo() {
  local asdlc_root="$TMP_ROOT/asdlc-shared-repo"
  local project_dir="$asdlc_root/projects/p1"
  local capture_dir="$TMP_ROOT/capture-shared-repo"
  local shared_repo="$TMP_ROOT/shared-class-repo"
  mkdir -p "$project_dir" "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  setup_codex_stub "$asdlc_root"
  setup_git_repo "$shared_repo"
  write_project_definition_two_ready "$project_dir" "$shared_repo" "$shared_repo"
  write_common_contract "$project_dir"
  setup_project_git "$project_dir"

  (
    cd "$TMP_ROOT"
    PATH="$asdlc_root/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_COMMON_CONTRACT_FILE="$project_dir/common_contract_definition.md" \
      "$asdlc_root/.commands/project_contract_reconciliation.sh" --path "$project_dir" --class backend --class frontend >/dev/null
  )

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" $'Unique repositories to inspect (scan each path once):\n- '"$shared_repo"$'\n- In-scope class-to-repository mappings:'
  assert_contains "$prompt" "- backend: $shared_repo"
  assert_contains "$prompt" "- frontend: $shared_repo"
}

test_fails_fast_when_run_from_repo_path
test_fails_when_path_argument_is_missing
test_fails_when_target_class_not_ready
test_fails_when_class_argument_missing
test_fails_when_rule_file_missing
test_runs_codex_with_contract_and_ready_repo_context_and_writes
test_blocks_model_mutating_project_definition
test_reconciles_multiple_target_classes_in_one_session
test_preserves_class_context_when_target_classes_share_repo

echo "All project contract reconciliation tests passed."
