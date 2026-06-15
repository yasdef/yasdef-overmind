#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_scan_repo_for_br.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/repo_br_scan_rule.md"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_business_context_filled_from_repo.sh"
CLASS_REPO_PATHS_LIB_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/class_repo_paths.sh"
SYNC_REPO_TO_DEFAULT_BRANCH_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/sync_repo_to_default_branch.sh"

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
    echo "Assertion failed: expected output to not contain: $needle" >&2
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

assert_file_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

assert_file_not_contains() {
  local path="$1"
  local needle="$2"
  if [[ -f "$path" && "$(cat "$path")" == *"$needle"* ]]; then
    echo "Assertion failed: expected file to not contain: $needle" >&2
    echo "Actual file content:" >&2
    cat "$path" >&2
    exit 1
  fi
}

create_synced_git_repo() {
  local repo_dir="$1"
  local repo_name="$2"
  local local_repo="$repo_dir/repositories/$repo_name"
  local remote_repo="$repo_dir/remotes/$repo_name.git"

  mkdir -p "$repo_dir/repositories" "$repo_dir/remotes"
  git init -q --bare "$remote_repo"
  mkdir -p "$local_repo"
  git -C "$local_repo" init -q
  git -C "$local_repo" checkout -q -b main
  git -C "$local_repo" config user.name "Test User"
  git -C "$local_repo" config user.email "test@example.com"
  git -C "$local_repo" remote add origin "$remote_repo"
  printf '%s\n' "$repo_name" >"$local_repo/README.md"
  git -C "$local_repo" add README.md
  git -C "$local_repo" commit -qm "seed $repo_name"
  git -C "$local_repo" push -q -u origin main
  git --git-dir="$remote_repo" symbolic-ref HEAD refs/heads/main
}

push_upstream_readme_change() {
  local repo_dir="$1"
  local repo_name="$2"
  local content="$3"
  local remote_repo="$repo_dir/remotes/$repo_name.git"
  local work_repo="$TMP_ROOT/upstream-work-$repo_name-$$-$RANDOM"

  git clone -q "$remote_repo" "$work_repo"
  git -C "$work_repo" checkout -q main
  git -C "$work_repo" config user.name "Test User"
  git -C "$work_repo" config user.email "test@example.com"
  printf '%s\n' "$content" >"$work_repo/README.md"
  git -C "$work_repo" add README.md
  git -C "$work_repo" commit -qm "upstream $repo_name update"
  git -C "$work_repo" push -q origin main
}

assert_no_rebase_state() {
  local repo_path="$1"
  local git_dir=""
  if ! git_dir="$(git -C "$repo_path" rev-parse --git-dir 2>/dev/null)"; then
    echo "Assertion failed: expected git dir to resolve for: $repo_path" >&2
    exit 1
  fi
  case "$git_dir" in
    /*) ;;
    *) git_dir="$repo_path/$git_dir" ;;
  esac

  if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
    echo "Assertion failed: expected failed git pull --rebase to be aborted for: $repo_path" >&2
    exit 1
  fi
}

setup_workspace() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/common_libs" \
    "$repo_dir/asdlc/projects/p1/feature-a" \
    "$repo_dir/repositories/backend" \
    "$repo_dir/repositories/frontend"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/repo_br_scan_rule.md"
  cp "$HELPER_SRC" "$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh"
  cp "$CLASS_REPO_PATHS_LIB_SRC" "$repo_dir/asdlc/common_libs/class_repo_paths.sh"
  cp "$SYNC_REPO_TO_DEFAULT_BRANCH_SRC" "$repo_dir/asdlc/common_libs/sync_repo_to_default_branch.sh"
  chmod +x \
    "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh" \
    "$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh" \
    "$repo_dir/asdlc/common_libs/sync_repo_to_default_branch.sh"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
repo_analyse | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  create_synced_git_repo "$repo_dir" "backend"
  create_synced_git_repo "$repo_dir" "frontend"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "ready"
      path: "$repo_dir/repositories/frontend"
    infrastructure:
      state: "deferred"
      path: ""

steps: []
EOF
}

seed_feature_br_summary() {
  local repo_dir="$1"
  local project_type_code="$2"
  cat >"$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" <<EOF_SUMMARY
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: $project_type_code
- ready_to_ears: false
EOF_SUMMARY
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
feature_root="${TEST_FEATURE_ROOT:?TEST_FEATURE_ROOT must be set}"
target_file="$feature_root/feature_br_summary.md"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"
cat >"$target_file" <<'DOC'
# Feature Business Requirements Summary

## 1. Document Meta
- project_type_code: B
- source_type: Repository scan
- last_updated: 2026-04-06
- ready_to_ears: false
DOC
if [[ -n "${TEST_SCAN_FILE:-}" ]]; then
  printf -- '- scanned_content: %s\n' "$(cat "$TEST_SCAN_FILE")" >>"$target_file"
fi
OUT
  chmod +x "$repo_dir/bin/codex"
}

write_backend_only_definition() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "deferred"
      path: ""

steps: []
EOF
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_scan_repo_for_br.sh" "$repo_dir/feature_scan_repo_for_br.sh"
  chmod +x "$repo_dir/feature_scan_repo_for_br.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_scan_repo_for_br.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_feature_summary_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-summary"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/feature_br_summary.md"
}

test_project_type_a_with_ready_repos_scans() {
  local repo_dir="$TMP_ROOT/repo-type-a-ready"
  local capture_dir="$TMP_ROOT/capture-type-a-ready"
  local backend_repo=""
  local frontend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "A"
  setup_codex_stub "$repo_dir"
  mkdir -p "$capture_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  frontend_repo="$(cd "$repo_dir/repositories/frontend" && pwd -P)"

  local out=""
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- backend: $backend_repo"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- frontend: $frontend_repo"
}

test_no_ready_classes_is_no_op_for_any_project_type() {
  local repo_dir="$TMP_ROOT/repo-no-ready-type-a"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "A"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
    frontend:
      state: "deferred"
      path: ""

steps: []
OUT

  local out=""
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"

  assert_contains "$out" "No ready repository paths found in meta_info.class_repo_paths; repo scan phase is a no-op."
  assert_not_contains "$out" "No usable repository paths found in meta_info.class_repo_paths"
}

test_no_ready_classes_is_no_op_for_type_b() {
  local repo_dir="$TMP_ROOT/repo-no-usable-repo-paths"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
    frontend:
      state: "deferred"
      path: ""

steps: []
OUT

  local out=""
  out="$(cd "$repo_dir/asdlc" && .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1)"

  assert_contains "$out" "No ready repository paths found in meta_info.class_repo_paths; repo scan phase is a no-op."
}

test_runs_codex_and_updates_feature_summary() {
  local repo_dir="$TMP_ROOT/repo-type-b"
  local capture_dir="$TMP_ROOT/capture-type-b"
  local backend_repo=""
  local frontend_repo=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  frontend_repo="$(cd "$repo_dir/repositories/frontend" && pwd -P)"

  local out
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "Target artifact: projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- backend: $backend_repo"
  assert_contains "$(cat "$capture_dir/codex_prompt.txt")" "- frontend: $frontend_repo"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- source_type: Repository scan"
}

test_mixed_state_project_scans_only_ready_classes() {
  local repo_dir="$TMP_ROOT/repo-mixed-state"
  local capture_dir="$TMP_ROOT/capture-mixed-state"
  local backend_repo=""
  local frontend_repo=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "C"
  setup_codex_stub "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  frontend_repo="$(cd "$repo_dir/repositories/frontend" && pwd -P)"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF
meta_info:
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "deferred"
      path: "$repo_dir/repositories/frontend"

steps: []
EOF

  cd "$repo_dir/asdlc" && PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
    .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" >/dev/null

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "- backend: $backend_repo"
  assert_not_contains "$prompt" "- frontend: $frontend_repo"
  assert_not_contains "$prompt" "Project type code:"
}

test_ready_repo_on_non_default_branch_blocks_without_artifact_update() {
  local repo_dir="$TMP_ROOT/repo-worker-branch"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  git -C "$backend_repo" checkout -q -b worker

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-worker-branch" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo is not on its default branch; planning reads upstream-synchronized merged truth only (D7) — check out the default branch and rerun"
  assert_file_not_exists "$TMP_ROOT/capture-worker-branch/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_repo_on_master_blocks_when_remote_default_is_main() {
  local repo_dir="$TMP_ROOT/repo-master-with-main-default"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  git -C "$backend_repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$backend_repo" checkout -q -b master

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-master-with-main-default" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo is not on its default branch; planning reads upstream-synchronized merged truth only (D7) — check out the default branch and rerun"
  assert_file_not_exists "$TMP_ROOT/capture-master-with-main-default/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_repo_with_main_and_master_but_no_remote_default_blocks_as_ambiguous() {
  local repo_dir="$TMP_ROOT/repo-ambiguous-local-default"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  git -C "$backend_repo" checkout -q -b master
  git -C "$backend_repo" checkout -q main
  if git -C "$backend_repo" symbolic-ref -q refs/remotes/origin/HEAD >/dev/null 2>&1; then
    git -C "$backend_repo" symbolic-ref -d refs/remotes/origin/HEAD
  fi

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-ambiguous-local-default" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo default branch is ambiguous; both main and master exist and no remote default is configured (D7) — configure the default branch and rerun"
  assert_file_not_exists "$TMP_ROOT/capture-ambiguous-local-default/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_ready_repo_with_uncommitted_change_blocks_without_artifact_update() {
  local repo_dir="$TMP_ROOT/repo-dirty"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  printf '%s\n' "dirty" >>"$backend_repo/README.md"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-dirty" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo has uncommitted changes; planning syncs and reads committed merged truth only (D7) — commit or stash and rerun"
  assert_file_not_exists "$TMP_ROOT/capture-dirty/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_ready_repo_without_upstream_blocks_without_artifact_update() {
  local repo_dir="$TMP_ROOT/repo-no-upstream"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  git -C "$backend_repo" branch --unset-upstream main

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-no-upstream" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo default branch has no upstream; planning cannot sync merged truth (D7) — configure upstream and rerun"
  assert_file_not_exists "$TMP_ROOT/capture-no-upstream/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_ready_repo_pull_rebase_failure_blocks_without_artifact_update() {
  local repo_dir="$TMP_ROOT/repo-rebase-failure"
  local backend_repo=""
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  printf '%s\n' "local divergent content" >"$backend_repo/README.md"
  git -C "$backend_repo" add README.md
  git -C "$backend_repo" commit -qm "local divergent update"
  push_upstream_readme_change "$repo_dir" "backend" "upstream divergent content"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-rebase-failure" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $backend_repo could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun"
  assert_no_rebase_state "$backend_repo"
  assert_file_not_exists "$TMP_ROOT/capture-rebase-failure/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_linked_worktree_pull_rebase_failure_aborts_real_gitdir_rebase() {
  local repo_dir="$TMP_ROOT/repo-worktree-rebase-failure"
  local backend_repo=""
  local linked_repo="$TMP_ROOT/backend-linked-worktree"
  mkdir -p "$repo_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  git -C "$backend_repo" checkout -q -b holder
  git -C "$backend_repo" worktree add -q "$linked_repo" main
  linked_repo="$(cd "$linked_repo" && pwd -P)"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF
meta_info:
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$linked_repo"
    frontend:
      state: "deferred"
      path: ""

steps: []
EOF

  printf '%s\n' "local linked worktree divergent content" >"$linked_repo/README.md"
  git -C "$linked_repo" add README.md
  git -C "$linked_repo" commit -qm "local linked worktree divergent update"
  push_upstream_readme_change "$repo_dir" "backend" "upstream linked worktree divergent content"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$TMP_ROOT/capture-worktree-rebase-failure" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "BLOCKED: $linked_repo could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun"
  assert_no_rebase_state "$linked_repo"
  assert_file_not_exists "$TMP_ROOT/capture-worktree-rebase-failure/codex_args.txt"
  assert_file_not_contains "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md" "- source_type: Repository scan"
}

test_ready_repo_syncs_upstream_before_scan_and_updates_artifact() {
  local repo_dir="$TMP_ROOT/repo-sync-success"
  local capture_dir="$TMP_ROOT/capture-sync-success"
  local backend_repo=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "B"
  setup_codex_stub "$repo_dir"
  write_backend_only_definition "$repo_dir"
  backend_repo="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  push_upstream_readme_change "$repo_dir" "backend" "upstream synchronized content"

  local out=""
  out="$(
    cd "$repo_dir/asdlc"
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_FEATURE_ROOT="$repo_dir/asdlc/projects/p1/feature-a" TEST_SCAN_FILE="$backend_repo/README.md" \
      .commands/feature_scan_repo_for_br.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_br_summary.md"
  assert_contains "$(cat "$backend_repo/README.md")" "upstream synchronized content"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- scanned_content: upstream synchronized content"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_feature_summary_missing
test_project_type_a_with_ready_repos_scans
test_no_ready_classes_is_no_op_for_any_project_type
test_no_ready_classes_is_no_op_for_type_b
test_runs_codex_and_updates_feature_summary
test_mixed_state_project_scans_only_ready_classes
test_ready_repo_on_non_default_branch_blocks_without_artifact_update
test_repo_on_master_blocks_when_remote_default_is_main
test_repo_with_main_and_master_but_no_remote_default_blocks_as_ambiguous
test_ready_repo_with_uncommitted_change_blocks_without_artifact_update
test_ready_repo_without_upstream_blocks_without_artifact_update
test_ready_repo_pull_rebase_failure_blocks_without_artifact_update
test_linked_worktree_pull_rebase_failure_aborts_real_gitdir_rebase
test_ready_repo_syncs_upstream_before_scan_and_updates_artifact

echo "All repo BR scan initializer tests passed."
