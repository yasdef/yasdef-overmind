#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPTION_1_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
OPTION_2_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
OPTION_3_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_update_project.sh"
COMMON_LIBS_SRC="$SOURCE_ROOT/overmind/scripts/common_libs"
OVERMIND_CLI_BUNDLE_REL_PATH="packages/asdlc-coordinator/dist/overmind.js"
SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-task-to-br"
SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SKILL_SOURCE_REL_PATH"
REPO_BR_SCAN_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-repo-br-scan"
REPO_BR_SCAN_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$REPO_BR_SCAN_SKILL_SOURCE_REL_PATH"
BR_CLARIFICATION_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-br-clarification"
BR_CLARIFICATION_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$BR_CLARIFICATION_SKILL_SOURCE_REL_PATH"
REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-requirements-ears"
REQUIREMENTS_EARS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH"
EARS_REVIEW_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-ears-review"
EARS_REVIEW_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$EARS_REVIEW_SKILL_SOURCE_REL_PATH"
CONTRACT_DELTA_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-contract-delta"
CONTRACT_DELTA_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$CONTRACT_DELTA_SKILL_SOURCE_REL_PATH"
SURFACE_MAP_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-surface-map"
SURFACE_MAP_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SURFACE_MAP_SKILL_SOURCE_REL_PATH"
SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-surface-map-enrich"
SURFACE_MAP_ENRICH_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH"
TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-technical-requirements"
TECHNICAL_REQUIREMENTS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH"
IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-implementation-slices"
IMPLEMENTATION_SLICES_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH"
PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-prerequisite-gaps"
PREREQUISITE_GAPS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH"
IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-implementation-plan"
IMPLEMENTATION_PLAN_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH"
PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-plan-semantic-review"
PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_zero_status() {
  local status="$1"
  if [[ "$status" -ne 0 ]]; then
    echo "Assertion failed: expected exit status 0, got $status" >&2
    exit 1
  fi
}

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero exit status" >&2
    exit 1
  fi
}

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
    echo "Assertion failed: expected output NOT to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
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

assert_file_content_equal() {
  local actual_path="$1"
  local expected_content="$2"
  local actual_content=""
  actual_content="$(cat "$actual_path")"
  if [[ "$actual_content" != "$expected_content" ]]; then
    echo "Assertion failed: file content mismatch: $actual_path" >&2
    echo "Expected:" >&2
    echo "$expected_content" >&2
    echo "Actual:" >&2
    echo "$actual_content" >&2
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

setup_repo_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/overmind/scripts/project_mgmt" \
    "$repo_dir/overmind/scripts" \
    "$repo_dir/overmind/scripts/common_libs"
  cp "$OPTION_1_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  cp "$OPTION_2_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  cp "$OPTION_3_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  cp "$COMMON_LIBS_SRC/project_setup_common.sh" "$repo_dir/overmind/scripts/common_libs/project_setup_common.sh"
  cp "$COMMON_LIBS_SRC/class_repo_paths.sh" "$repo_dir/overmind/scripts/common_libs/class_repo_paths.sh"
  cp "$COMMON_LIBS_SRC/check_implementation_plan_readiness.sh" "$repo_dir/overmind/scripts/common_libs/check_implementation_plan_readiness.sh"
  cp "$COMMON_LIBS_SRC/list_committed_sibling_features.sh" "$repo_dir/overmind/scripts/common_libs/list_committed_sibling_features.sh"
  cp "$COMMON_LIBS_SRC/persist_class_repo_attach.sh" "$repo_dir/overmind/scripts/common_libs/persist_class_repo_attach.sh"
  cp "$COMMON_LIBS_SRC/sync_repo_to_default_branch.sh" "$repo_dir/overmind/scripts/common_libs/sync_repo_to_default_branch.sh"
  cp "$SOURCE_ROOT/overmind/scripts/project_mgmt/init_progress_scanner.sh" "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh"
  cp "$SOURCE_ROOT/overmind/scripts/init_project_stack_blueprints.sh" "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  cp "$SOURCE_ROOT/overmind/scripts/project_mgmt/project_add_feature_e2e.sh" "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
  cp "$SOURCE_ROOT/overmind/scripts/project_mgmt/project_register_worker.sh" "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  cp "$SOURCE_ROOT/overmind/scripts/init_common_contract_definition.sh" "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  cp "$SOURCE_ROOT/overmind/scripts/project_mgmt/project_contract_reconciliation.sh" "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
  cp "$SOURCE_ROOT/overmind/scripts/feature_br_scaffold.sh" "$repo_dir/overmind/scripts/feature_br_scaffold.sh"
  cp "$SOURCE_ROOT/overmind/scripts/feature_assing_workers.sh" "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  cp -R "$SOURCE_ROOT/overmind/rules" "$repo_dir/overmind/rules"
  cp -R "$SOURCE_ROOT/overmind/templates" "$repo_dir/overmind/templates"
  cp -R "$SOURCE_ROOT/overmind/golden_examples" "$repo_dir/overmind/golden_examples"
  cp -R "$SOURCE_ROOT/overmind/scripts/helper" "$repo_dir/overmind/scripts/helper"
  cp -R "$SOURCE_ROOT/overmind/setup" "$repo_dir/overmind/setup"
  mkdir -p "$repo_dir/packages/asdlc-coordinator/dist"
  cat >"$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH" <<'OUT'
#!/usr/bin/env node
console.log("stub overmind");
OUT
  chmod +x "$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH"
  mkdir -p "$repo_dir/$(dirname "$SKILL_SOURCE_REL_PATH")"
  cp -R "$SKILL_SOURCE_DIR_SRC" "$repo_dir/$SKILL_SOURCE_REL_PATH"
  cp -R "$REPO_BR_SCAN_SKILL_SOURCE_DIR_SRC" "$repo_dir/$REPO_BR_SCAN_SKILL_SOURCE_REL_PATH"
  cp -R "$BR_CLARIFICATION_SKILL_SOURCE_DIR_SRC" "$repo_dir/$BR_CLARIFICATION_SKILL_SOURCE_REL_PATH"
  cp -R "$REQUIREMENTS_EARS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH"
  cp -R "$EARS_REVIEW_SKILL_SOURCE_DIR_SRC" "$repo_dir/$EARS_REVIEW_SKILL_SOURCE_REL_PATH"
  cp -R "$CONTRACT_DELTA_SKILL_SOURCE_DIR_SRC" "$repo_dir/$CONTRACT_DELTA_SKILL_SOURCE_REL_PATH"
  cp -R "$SURFACE_MAP_SKILL_SOURCE_DIR_SRC" "$repo_dir/$SURFACE_MAP_SKILL_SOURCE_REL_PATH"
  cp -R "$SURFACE_MAP_ENRICH_SKILL_SOURCE_DIR_SRC" "$repo_dir/$SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH"
  cp -R "$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH"
  cp -R "$IMPLEMENTATION_SLICES_SKILL_SOURCE_DIR_SRC" "$repo_dir/$IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH"
  cp -R "$PREREQUISITE_GAPS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH"
  cp -R "$IMPLEMENTATION_PLAN_SKILL_SOURCE_DIR_SRC" "$repo_dir/$IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH"
  cp -R "$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_DIR_SRC" "$repo_dir/$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH"
  chmod +x \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh" \
    "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh" \
    "$repo_dir/overmind/scripts/init_common_contract_definition.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh" \
    "$repo_dir/overmind/scripts/feature_br_scaffold.sh" \
    "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  find "$repo_dir/overmind/scripts/helper" -maxdepth 1 -type f -exec chmod +x {} +
}

setup_git_repo_with_identity() {
  local repo_dir="$1"
  setup_repo_layout "$repo_dir"
  (
    cd "$repo_dir"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "seed" >README.md
    git add README.md overmind
    git commit -qm "seed"
  )
}

bootstrap_asdlc_workspace() {
  local repo_dir="$1"
  local bootstrap_parent="$2"
  local asdlc_root="$bootstrap_parent/asdlc"
  (
    cd "$repo_dir"
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh >/dev/null
  )
  printf '%s' "$asdlc_root"
}

write_project_definition() {
  local def_path="$1"
  local project_id="$2"
  local type_code="$3"
  local type_label="$4"
  shift 4
  local c="" s="" p=""

  {
    echo "meta_info:"
    echo "  project_id: \"$project_id\""
    echo "  project_classes:"
    for pair in "$@"; do
      IFS='|' read -r c s p <<<"$pair"
      echo "    - $c"
    done
    echo "  project_type_code: \"$type_code\""
    echo "  project_type_label: \"$type_label\""
    echo "  class_repo_paths:"
    for pair in "$@"; do
      IFS='|' read -r c s p <<<"$pair"
      echo "    $c:"
      echo "      state: \"$s\""
      echo "      path: \"$p\""
    done
    echo ""
    echo "steps:"
    echo "  - step_name: \"Step 1\""
    echo "    status: \"pending\""
  } >"$def_path"
}

create_test_project() {
  local asdlc_root="$1"
  local project_id="$2"
  local type_code="$3"
  local type_label="$4"
  shift 4

  local project_dir="$asdlc_root/projects/$project_id"
  mkdir -p "$project_dir"
  write_project_definition "$project_dir/init_progress_definition.yaml" "$project_id" "$type_code" "$type_label" "$@"
}

create_valid_repo_dir() {
  local path="$1"
  mkdir -p "$path"
  echo "placeholder" >"$path/placeholder.txt"
  git -C "$path" init -q
}

test_update_project_quits_at_project_prompt() {
  local repo_dir="$TMP_ROOT/repo-update-quit-project"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-quit-project"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local status=0
  set +e
  printf 'q\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_file_content_equal "$def_path" "$before"
}

test_update_project_quits_at_class_prompt() {
  local repo_dir="$TMP_ROOT/repo-update-quit-class"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-quit-class"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local status=0
  set +e
  printf '1\nq\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_file_content_equal "$def_path" "$before"
}

test_update_project_quits_at_path_prompt() {
  local repo_dir="$TMP_ROOT/repo-update-quit-path"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-quit-path"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local status=0
  set +e
  printf '1\n1\nq\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_file_content_equal "$def_path" "$before"
}

test_update_project_invalid_path_reprompts_then_succeeds() {
  local repo_dir="$TMP_ROOT/repo-update-invalid-path"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-invalid-path"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-invalid-path-test"
  create_valid_repo_dir "$valid_repo"

  local empty_dir="$TMP_ROOT/empty-dir-invalid-path-test"
  local non_git_dir="$TMP_ROOT/non-git-dir-invalid-path-test"
  mkdir -p "$empty_dir"
  mkdir -p "$non_git_dir"
  echo "not git" >"$non_git_dir/README.md"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n\n/nonexistent/path/xyz\n/tmp/not_a_dir_placeholder\n%s\n%s\n%s\n3\n' "$empty_dir" "$non_git_dir" "$valid_repo" | \
    "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "Repo path cannot be empty"
  assert_contains "$out" "does not exist"
  assert_contains "$out" "must point to a non-empty directory"
  assert_contains "$out" "Repo path must contain .git: $non_git_dir"

  local after_type=""
  after_type="$(grep '^  project_type_code:' "$def_path" | sed 's/.*"\(.*\)".*/\1/')"
  assert_equal "A" "$after_type"
  assert_contains "$(cat "$def_path")" "state: \"ready\""
  assert_contains "$(cat "$def_path")" "path: \"$valid_repo\""
  assert_contains "$(cat "$def_path")" "policy: \"C\""
}

test_update_project_only_deferred_classes_shown() {
  local repo_dir="$TMP_ROOT/repo-update-deferred-only"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-deferred-only"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local ready_path="$TMP_ROOT/ready-repo-deferred-only"
  create_valid_repo_dir "$ready_path"

  create_test_project "$asdlc_root" "proj-001" "B" "Existing project with partial context" \
    "backend|ready|$ready_path" "frontend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-deferred-only"
  create_valid_repo_dir "$valid_repo"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n%s\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "frontend"
  assert_not_contains "$out" "1. backend"
}

test_update_project_all_ready_nothing_to_add() {
  local repo_dir="$TMP_ROOT/repo-update-all-ready"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-all-ready"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local ready_path="$TMP_ROOT/ready-repo-all-ready"
  create_valid_repo_dir "$ready_path"

  create_test_project "$asdlc_root" "proj-001" "B" "Existing project with partial context" \
    "backend|ready|$ready_path"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "Nothing to add"
}

test_update_project_successful_attach_flips_state_path_and_policy() {
  local repo_dir="$TMP_ROOT/repo-update-attach-state-path-policy"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-attach-state-path-policy"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "B" "Existing project with partial context" \
    "backend|deferred|" "frontend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-attach-two-lines"
  create_valid_repo_dir "$valid_repo"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local status=0
  set +e
  printf '1\n1\n%s\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"

  local after=""
  after="$(cat "$def_path")"

  assert_contains "$after" "state: \"ready\""
  assert_contains "$after" "path: \"$valid_repo\""
  assert_contains "$after" "policy: \"C\""
  assert_contains "$after" "state: \"deferred\""

  local diff_lines=""
  diff_lines="$(diff <(echo "$before") <(echo "$after") | grep '^[<>]' | wc -l | tr -d ' ' || true)"
  assert_equal "5" "$diff_lines"

  assert_contains "$after" "steps:"
}

test_update_project_corrupted_state_exits_clean_without_mutation() {
  local repo_dir="$TMP_ROOT/repo-update-shape-mismatch"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-shape-mismatch"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|corrupted|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "Nothing to add"
  assert_file_content_equal "$def_path" "$before"
}

test_update_project_type_a_reclassify_to_b() {
  local repo_dir="$TMP_ROOT/repo-update-reclassify-b"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-reclassify-b"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-reclassify-b"
  create_valid_repo_dir "$valid_repo"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"

  local status=0
  set +e
  printf '1\n1\n%s\n1\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$(cat "$def_path")" 'project_type_code: "B"'
  assert_contains "$(cat "$def_path")" 'project_type_label: "Existing project with partial context"'
  assert_contains "$(cat "$def_path")" "state: \"ready\""
}

test_update_project_type_a_reclassify_to_c() {
  local repo_dir="$TMP_ROOT/repo-update-reclassify-c"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-reclassify-c"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-reclassify-c"
  create_valid_repo_dir "$valid_repo"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"

  local status=0
  set +e
  printf '1\n1\n%s\n2\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$(cat "$def_path")" 'project_type_code: "C"'
  assert_contains "$(cat "$def_path")" 'project_type_label: "Existing project with code-first context"'
}

test_update_project_type_a_keep_when_decline() {
  local repo_dir="$TMP_ROOT/repo-update-keep-a"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-keep-a"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-keep-a"
  create_valid_repo_dir "$valid_repo"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"

  for input in "3" "q" ""; do
    sed -i.bak 's/state: "ready"/state: "deferred"/' "$def_path"
    sed -i.bak 's|path: ".*"|path: ""|' "$def_path"
    sed -i.bak 's/project_type_code: "B"/project_type_code: "A"/' "$def_path"
    sed -i.bak 's/project_type_code: "C"/project_type_code: "A"/' "$def_path"
    rm -f "$def_path.bak"

    local status=0
    set +e
    printf '1\n1\n%s\n%s\n' "$valid_repo" "$input" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
    status=$?
    set -e

    assert_zero_status "$status"
    assert_contains "$(cat "$def_path")" 'project_type_code: "A"'
  done
}

test_update_project_type_a_no_reclassify_when_still_deferred() {
  local repo_dir="$TMP_ROOT/repo-update-no-reclassify-deferred"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-no-reclassify-deferred"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" \
    "backend|deferred|" "frontend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-no-reclassify-deferred"
  create_valid_repo_dir "$valid_repo"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n%s\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_not_contains "$out" "Reclassify?"
  assert_contains "$(cat "$def_path")" 'project_type_code: "A"'
}

test_update_project_type_b_no_reclassify() {
  local repo_dir="$TMP_ROOT/repo-update-type-b-no-reclassify"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-type-b-no-reclassify"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "B" "Existing project with partial context" \
    "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-type-b-no-reclassify"
  create_valid_repo_dir "$valid_repo"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n%s\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_not_contains "$out" "Reclassify?"
  assert_contains "$(cat "$asdlc_root/projects/proj-001/init_progress_definition.yaml")" 'project_type_code: "B"'
}

test_update_project_stale_artifacts_warning_on_reclassify() {
  local repo_dir="$TMP_ROOT/repo-update-stale-warning"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-stale-warning"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-stale-warning"
  create_valid_repo_dir "$valid_repo"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n%s\n1\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "type-A artifacts"
  assert_contains "$out" "may need to be regenerated"
}

test_update_project_stale_artifacts_suppressed_on_decline() {
  local repo_dir="$TMP_ROOT/repo-update-stale-suppressed"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-stale-suppressed"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local valid_repo="$TMP_ROOT/valid-repo-stale-suppressed"
  create_valid_repo_dir "$valid_repo"

  local out=""
  local status=0
  set +e
  out="$(printf '1\n1\n%s\n3\n' "$valid_repo" | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_not_contains "$out" "type-A artifacts"
}

test_update_project_quits_at_project_prompt
test_update_project_quits_at_class_prompt
test_update_project_quits_at_path_prompt
test_update_project_invalid_path_reprompts_then_succeeds
test_update_project_only_deferred_classes_shown
test_update_project_all_ready_nothing_to_add
test_update_project_successful_attach_flips_state_path_and_policy
test_update_project_corrupted_state_exits_clean_without_mutation
test_update_project_type_a_reclassify_to_b
test_update_project_type_a_reclassify_to_c
test_update_project_type_a_keep_when_decline
test_update_project_type_a_no_reclassify_when_still_deferred
test_update_project_type_b_no_reclassify
test_update_project_stale_artifacts_warning_on_reclassify
test_update_project_stale_artifacts_suppressed_on_decline

echo "All project_setup_update_project tests passed."
