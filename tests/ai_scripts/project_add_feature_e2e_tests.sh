#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
PROJECT_SETUP_COMMON_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/project_setup_common.sh"
CLASS_REPO_PATHS_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/class_repo_paths.sh"
PERSIST_CLASS_REPO_ATTACH_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/persist_class_repo_attach.sh"

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

assert_zero_status() {
  local status="$1"
  if [[ "$status" -ne 0 ]]; then
    echo "Assertion failed: expected zero status, got $status" >&2
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

setup_git_repo() {
  local repo_root="$1"

  mkdir -p "$repo_root"
  if [[ -z "$(find "$repo_root" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "seed" >"$repo_root/README.md"
  fi
  git -C "$repo_root" init >/dev/null 2>&1
  git -C "$repo_root" config user.name "Test User"
  git -C "$repo_root" config user.email "test@example.com"
  git -C "$repo_root" add -A
  git -C "$repo_root" commit -m "Initial commit" >/dev/null 2>&1
}

write_external_sources_yaml() {
  local target_path="$1"
  shift || true

  mkdir -p "$(dirname "$target_path")"

  if [[ "$#" -eq 0 ]]; then
    cat >"$target_path" <<'OUT'
sources: []
OUT
    return 0
  fi

  {
    echo "sources:"
    local entry=""
    local name=""
    local source_type=""
    for entry in "$@"; do
      name="${entry%%|*}"
      source_type="${entry#*|}"
      if [[ "$source_type" == "$entry" ]]; then
        source_type="generic"
      fi
      printf '  - name: %s\n' "$name"
      printf '    type: %s\n' "$source_type"
    done
  } >"$target_path"
}

write_feature_script_stub() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_LOG_FILE:?TEST_LOG_FILE must be set}"
feature_path=""
touch_target=""
map_entry=""
map_script=""
map_value=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature_path)
      shift
      [[ $# -gt 0 ]] || {
        echo "missing feature_path" >&2
        exit 1
      }
      feature_path="$1"
      ;;
  esac
  shift
done

printf '%s --feature_path %s\n' "$(basename "$0")" "$feature_path" >>"$log_file"

if [[ -n "${TEST_SCRIPT_TOUCH_MAP:-}" ]]; then
  while IFS= read -r map_entry; do
    [[ -n "$map_entry" ]] || continue
    map_script="${map_entry%%=*}"
    map_value="${map_entry#*=}"
    if [[ "$map_script" == "$(basename "$0")" ]]; then
      touch_target="$map_value"
      break
    fi
  done <<<"${TEST_SCRIPT_TOUCH_MAP}"
fi

if [[ -n "$touch_target" ]]; then
  touch_path="$PWD/$touch_target"
  mkdir -p "$(dirname "$touch_path")"
  printf 'updated by %s\n' "$(basename "$0")" >"$touch_path"
fi

if [[ "${TEST_FAIL_SCRIPT:-}" == "$(basename "$0")" ]]; then
  echo "simulated failure from $(basename "$0")" >&2
  exit "${TEST_FAIL_SCRIPT_EXIT_CODE:-17}"
fi
OUT
  chmod +x "$target_path"
}

write_repo_surface_script_stub() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_LOG_FILE:?TEST_LOG_FILE must be set}"
feature_path=""
selection=""
selected_class=""
map_suffix=""

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature_path)
      shift
      [[ $# -gt 0 ]] || {
        echo "missing feature_path" >&2
        exit 1
      }
      feature_path="$1"
      ;;
  esac
  shift
done

printf '%s --feature_path %s\n' "$(basename "$0")" "$feature_path" >>"$log_file"
echo "Select target to analyze now (number or class name):" >&2
if ! IFS= read -r selection; then
  selection=""
fi
selection="$(trim_value "$selection")"
selection="$(printf '%s' "$selection" | tr '[:upper:]' '[:lower:]')"

if [[ "$selection" =~ ^[0-9]+$ ]]; then
  IFS=',' read -r -a class_order <<<"${TEST_REPO_SURFACE_CLASS_ORDER:-backend,frontend,mobile}"
  idx=$((selection - 1))
  if (( idx >= 0 && idx < ${#class_order[@]} )); then
    selected_class="$(trim_value "${class_order[$idx]}")"
    selected_class="$(printf '%s' "$selected_class" | tr '[:upper:]' '[:lower:]')"
  fi
else
  selected_class="$selection"
fi

case "$selected_class" in
  backend) map_suffix="backend" ;;
  frontend) map_suffix="frontend" ;;
  mobile) map_suffix="mobile" ;;
  *)
    exit 0
    ;;
esac

if [[ "${TEST_REPO_SURFACE_TOUCH_MAPS:-1}" != "1" ]]; then
  exit 0
fi

if [[ "${TEST_FAIL_SCRIPT:-}" == "$(basename "$0")" ]]; then
  echo "simulated failure from $(basename "$0")" >&2
  exit "${TEST_FAIL_SCRIPT_EXIT_CODE:-17}"
fi

map_path="$PWD/$feature_path/project_surface_struct_resp_map_$map_suffix.md"
mkdir -p "$(dirname "$map_path")"
cat >"$map_path" <<DOC
# $selected_class surface map
DOC
OUT
  chmod +x "$target_path"
}

setup_workspace() {
  local asdlc_root="$1"

  mkdir -p "$asdlc_root/.commands" "$asdlc_root/common_libs" "$asdlc_root/projects/project-a"

  cp "$SCRIPT_SRC" "$asdlc_root/.commands/project_add_feature_e2e.sh"
  chmod +x "$asdlc_root/.commands/project_add_feature_e2e.sh"
  cp "$PROJECT_SETUP_COMMON_SRC" "$asdlc_root/common_libs/project_setup_common.sh"
  cp "$CLASS_REPO_PATHS_SRC" "$asdlc_root/common_libs/class_repo_paths.sh"
  cp "$PERSIST_CLASS_REPO_ATTACH_SRC" "$asdlc_root/common_libs/persist_class_repo_attach.sh"
  chmod +x "$asdlc_root/common_libs/project_setup_common.sh" "$asdlc_root/common_libs/class_repo_paths.sh" "$asdlc_root/common_libs/persist_class_repo_attach.sh"

  cat >"$asdlc_root/.commands/feature_br_scaffold.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_LOG_FILE:?TEST_LOG_FILE must be set}"
project_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || {
        echo "missing path" >&2
        exit 1
      }
      project_path="$1"
      ;;
  esac
  shift
done

[[ -n "$project_path" ]] || {
  echo "missing --path" >&2
  exit 1
}

feature_rel="${TEST_SCAFFOLD_FEATURE_REL:-$project_path/feature-alpha}"
mkdir -p "$PWD/$feature_rel"
printf '%s --path %s\n' "$(basename "$0")" "$project_path" >>"$log_file"
if [[ "${TEST_SCAFFOLD_OMIT_CREATED_LINE:-0}" != "1" ]]; then
  printf '%sCreated feature folder: %s\n' "${TEST_SCAFFOLD_CREATED_PREFIX:-}" "$feature_rel"
fi
if [[ "${TEST_SCAFFOLD_PRINT_UPDATED_LINE:-0}" == "1" ]]; then
  printf 'Updated %s/feature_br_summary.md\n' "$feature_rel"
fi

if [[ "${TEST_FAIL_SCRIPT:-}" == "$(basename "$0")" ]]; then
  echo "simulated failure from $(basename "$0")" >&2
  exit "${TEST_FAIL_SCRIPT_EXIT_CODE:-17}"
fi
OUT
  chmod +x "$asdlc_root/.commands/feature_br_scaffold.sh"

  cat >"$asdlc_root/.commands/init_progress_scanner.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_LOG_FILE:?TEST_LOG_FILE must be set}"
feature_path=""
scanner_line="${TEST_SCANNER_NEXT_LINE:-next step: none}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || {
        echo "missing path" >&2
        exit 1
      }
      feature_path="$1"
      ;;
  esac
  shift
done

[[ -n "$feature_path" ]] || {
  echo "missing --path" >&2
  exit 1
}

if [[ -n "${TEST_SCANNER_RESPONSE_MAP:-}" ]]; then
  while IFS= read -r map_entry; do
    [[ -n "$map_entry" ]] || continue
    map_path="${map_entry%%=*}"
    map_value="${map_entry#*=}"
    if [[ "$map_path" == "$feature_path" ]]; then
      scanner_line="$map_value"
      break
    fi
  done <<<"${TEST_SCANNER_RESPONSE_MAP}"
fi

printf '%s --path %s\n' "$(basename "$0")" "$feature_path" >>"$log_file"
printf '# Overmind Bootstrap Checklist\n'
printf '%s\n' "$scanner_line"
OUT
  chmod +x "$asdlc_root/.commands/init_progress_scanner.sh"

  cat >"$asdlc_root/.commands/project_contract_reconciliation.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_LOG_FILE:?TEST_LOG_FILE must be set}"
project_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      shift
      project_path="${1:-}"
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
  shift
done

printf '%s --path %s\n' "$(basename "$0")" "$project_path" >>"$log_file"
if [[ "${TEST_FAIL_RECONCILIATION:-0}" == "1" ]]; then
  echo "simulated reconciliation failure" >&2
  exit 17
fi
OUT
  chmod +x "$asdlc_root/.commands/project_contract_reconciliation.sh"

  write_feature_script_stub "$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_task_to_br.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_user_br_clarification.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_br_to_ears.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_contract_delta.sh"
  write_repo_surface_script_stub "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_technical_requirements.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_implementation_slices.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_implementation_plan.sh"
  write_feature_script_stub "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"

  cat >"$asdlc_root/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT

  cat >"$asdlc_root/projects/project-a/init_progress_definition.yaml" <<'OUT'
steps: []
OUT
}

read_log() {
  local path="$1"
  if [[ -f "$path" ]]; then
    cat "$path"
  fi
}

write_project_definition_with_backend_deferred() {
  local project_path="$1"

  cat >"$project_path/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "project-a"
  project_classes:
    - backend
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
steps: []
OUT
}

write_backend_blueprint_with_planned_repo_path() {
  local project_path="$1"
  local planned_repo_path="$2"

  cat >"$project_path/project_stack_blueprint_backend.md" <<OUT
# Project Stack Blueprint - Backend

## 1. Meta
- class: backend
- repo_name: backend
- service_name: backend
- planned_repo_path: $planned_repo_path (planned)
- group_id: com.example
- last_updated: 2026-06-14
OUT
}

read_backend_definition_field() {
  local definition_path="$1"
  local field_name="$2"

  awk -v field="$field_name" '
    BEGIN { in_block = 0; in_backend = 0 }
    /^  class_repo_paths:[[:space:]]*$/ { in_block = 1; next }
    in_block && /^[^ ]/ { in_block = 0; in_backend = 0 }
    in_block && /^    backend:[[:space:]]*$/ { in_backend = 1; next }
    in_block && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ { in_backend = 0; next }
    in_backend && $0 ~ "^[[:space:]]*" field ":" {
      line = $0
      sub("^[[:space:]]*" field ":[[:space:]]*", "", line)
      gsub(/^"|"$/, "", line)
      print line
      exit
    }
  ' "$definition_path"
}

test_deferred_class_prompt_yes_attaches_planned_repo_with_policy_c() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-yes"
  local log_file="$TMP_ROOT/asdlc-attach-yes.log"
  local planned_repo="$TMP_ROOT/planned-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Class 'backend' blueprint declares planned repo path $planned_repo and a scannable repository exists there."
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_equal "$planned_repo" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "path")"
  assert_equal "C" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "policy")"
  assert_file_exists "$asdlc_root/projects/project-a/.contract_reconciled_backend"
  assert_contains "$(cat "$log_file")" "project_contract_reconciliation.sh --path $asdlc_root/projects/project-a"
}

test_deferred_class_prompt_no_leaves_class_deferred() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-no"
  local log_file="$TMP_ROOT/asdlc-attach-no.log"
  local planned_repo="$TMP_ROOT/no-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'n\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Class 'backend' blueprint declares planned repo path $planned_repo and a scannable repository exists there."
  assert_equal "deferred" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_equal "" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "policy")"
}

test_deferred_class_prompt_alternate_path_attaches_alternate_repo() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-alt"
  local log_file="$TMP_ROOT/asdlc-attach-alt.log"
  local planned_repo="$TMP_ROOT/alt-planned-backend-repo"
  local alternate_repo="$TMP_ROOT/alt-actual-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo" "$alternate_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  setup_git_repo "$alternate_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '%s\n' "$alternate_repo"
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Class 'backend' blueprint declares planned repo path $planned_repo and a scannable repository exists there."
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_equal "$alternate_repo" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "path")"
  assert_equal "C" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "policy")"
}

test_deferred_class_prompt_invalid_alternate_path_reprompts_once_then_attaches() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-alt-retry"
  local log_file="$TMP_ROOT/asdlc-attach-alt-retry.log"
  local planned_repo="$TMP_ROOT/alt-retry-planned-backend-repo"
  local invalid_alternate_repo="$TMP_ROOT/alt-retry-missing-backend-repo"
  local retry_repo="$TMP_ROOT/alt-retry-actual-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo" "$retry_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  setup_git_repo "$retry_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '%s\n' "$invalid_alternate_repo"
      printf '%s\n' "$retry_repo"
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Repo path is not a directory: $invalid_alternate_repo"
  assert_contains "$out" "Enter alternate repo path for class 'backend' or leave blank to skip:"
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_equal "$retry_repo" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "path")"
  assert_equal "C" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "policy")"
}

test_deferred_class_with_nonexistent_planned_repo_path_stays_silent() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-missing-planned"
  local log_file="$TMP_ROOT/asdlc-attach-missing-planned.log"
  local missing_repo="$TMP_ROOT/missing-planned-backend-repo"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$missing_repo"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_not_contains "$out" "Attach it and switch this class to repo-backed"
  assert_equal "deferred" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
}

test_deferred_class_attach_skips_reconciliation_when_marker_exists() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-marker-exists"
  local log_file="$TMP_ROOT/asdlc-attach-marker-exists.log"
  local planned_repo="$TMP_ROOT/marker-exists-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"
  : >"$asdlc_root/projects/project-a/.contract_reconciled_backend"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Class 'backend' blueprint declares planned repo path $planned_repo and a scannable repository exists there."
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_not_contains "$(cat "$log_file")" "project_contract_reconciliation.sh"
}

test_ready_class_without_reconciliation_marker_retries_on_next_run() {
  local asdlc_root="$TMP_ROOT/asdlc-attach-retry-reconciliation"
  local log_file="$TMP_ROOT/asdlc-attach-retry-reconciliation.log"
  local planned_repo="$TMP_ROOT/retry-reconciliation-backend-repo"
  mkdir -p "$asdlc_root" "$planned_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  local status=0
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_FAIL_RECONCILIATION=1 TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "simulated reconciliation failure"
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_file_not_exists "$asdlc_root/projects/project-a/.contract_reconciled_backend"
  assert_contains "$(cat "$log_file")" "project_contract_reconciliation.sh --path $asdlc_root/projects/project-a"

  : >"$log_file"
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_not_contains "$out" "Attach it and switch this class to repo-backed"
  assert_file_exists "$asdlc_root/projects/project-a/.contract_reconciled_backend"
  assert_contains "$(cat "$log_file")" "project_contract_reconciliation.sh --path $asdlc_root/projects/project-a"
}

test_alternate_attach_reconciliation_failure_does_not_prompt_for_another_path() {
  local asdlc_root="$TMP_ROOT/asdlc-alt-reconciliation-fail"
  local log_file="$TMP_ROOT/asdlc-alt-reconciliation-fail.log"
  local planned_repo="$TMP_ROOT/alt-reconciliation-planned-repo"
  local alternate_repo="$TMP_ROOT/alt-reconciliation-selected-repo"
  local second_repo="$TMP_ROOT/alt-reconciliation-second-repo"
  mkdir -p "$asdlc_root" "$planned_repo" "$alternate_repo" "$second_repo"
  setup_workspace "$asdlc_root"
  setup_git_repo "$planned_repo"
  setup_git_repo "$alternate_repo"
  setup_git_repo "$second_repo"
  write_project_definition_with_backend_deferred "$asdlc_root/projects/project-a"
  write_backend_blueprint_with_planned_repo_path "$asdlc_root/projects/project-a" "$planned_repo"

  local out=""
  local status=0
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '%s\n' "$alternate_repo"
      printf '%s\n' "$second_repo"
    } | TEST_LOG_FILE="$log_file" TEST_FAIL_RECONCILIATION=1 TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "simulated reconciliation failure"
  assert_not_contains "$out" "Enter alternate repo path for class 'backend' or leave blank to skip:"
  assert_equal "ready" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "state")"
  assert_equal "$alternate_repo" "$(read_backend_definition_field "$asdlc_root/projects/project-a/init_progress_definition.yaml" "path")"
  assert_file_not_exists "$asdlc_root/projects/project-a/.contract_reconciled_backend"
}

test_without_path_uses_only_project_in_workspace() {
  local asdlc_root="$TMP_ROOT/asdlc-single-project-autodetect"
  local log_file="$TMP_ROOT/asdlc-single-project-autodetect.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh 2>&1
  )"

  assert_contains "$out" "No --path provided. Found one ASDLC project; using path: projects/project-a"
  assert_contains "$out" "Saved feature_path: projects/project-a/feature-alpha"
  assert_not_contains "$out" "Multiple projects found under ASDLC projects"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
}

test_without_path_prompts_for_project_when_multiple_exist() {
  local asdlc_root="$TMP_ROOT/asdlc-multi-project-autodetect"
  local log_file="$TMP_ROOT/asdlc-multi-project-autodetect.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-b"
  cat >"$asdlc_root/projects/project-b/init_progress_definition.yaml" <<'OUT'
steps: []
OUT

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-b/feature-beta" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh 2>&1
  )"

  assert_contains "$out" "No --path provided. Multiple projects found under ASDLC projects:"
  assert_contains "$out" "1) project-a [projects/project-a]"
  assert_contains "$out" "2) project-b [projects/project-b]"
  assert_contains "$out" "Selected project: projects/project-b"
  assert_contains "$out" "Saved feature_path: projects/project-b/feature-beta"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "feature_br_scaffold.sh --path projects/project-b"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-b/feature-beta"
  assert_not_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
}

test_without_path_can_finish_when_multiple_projects_exist() {
  local asdlc_root="$TMP_ROOT/asdlc-multi-project-finish"
  local log_file="$TMP_ROOT/asdlc-multi-project-finish.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-b"
  cat >"$asdlc_root/projects/project-b/init_progress_definition.yaml" <<'OUT'
steps: []
OUT

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'q\n'
    } | TEST_LOG_FILE="$log_file" .commands/project_add_feature_e2e.sh 2>&1
  )"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "Execution finished: no project selected."
  assert_equal "" "$(read_log "$log_file")"
}

test_scaffold_first_run_persists_feature_path_and_calls_scanner() {
  local asdlc_root="$TMP_ROOT/asdlc-scaffold-persist"
  local log_file="$TMP_ROOT/asdlc-scaffold-persist.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Saved feature_path: projects/project-a/feature-alpha"
  assert_contains "$out" "# Overmind Bootstrap Checklist"
  assert_contains "$out" "next step: none"

  local state_file="$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  assert_file_exists "$state_file"
  assert_equal "feature_path=projects/project-a/feature-alpha" "$(cat "$state_file")"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
}

test_scaffold_path_capture_accepts_prefixed_created_line() {
  local asdlc_root="$TMP_ROOT/asdlc-scaffold-prefixed-created"
  local log_file="$TMP_ROOT/asdlc-scaffold-prefixed-created.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-prefixed" \
      TEST_SCAFFOLD_CREATED_PREFIX="[info] " TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Saved feature_path: projects/project-a/feature-prefixed"
  assert_contains "$out" "next step: none"
}

test_scaffold_path_capture_falls_back_to_updated_line() {
  local asdlc_root="$TMP_ROOT/asdlc-scaffold-fallback-updated"
  local log_file="$TMP_ROOT/asdlc-scaffold-fallback-updated.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-from-updated" \
      TEST_SCAFFOLD_OMIT_CREATED_LINE="1" TEST_SCAFFOLD_PRINT_UPDATED_LINE="1" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Saved feature_path: projects/project-a/feature-from-updated"
  assert_contains "$out" "next step: none"
}

test_split_4_1_and_4_2_execute_in_order_with_messages() {
  local asdlc_root="$TMP_ROOT/asdlc-split-order"
  local log_file="$TMP_ROOT/asdlc-split-order.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
      printf 'y\n'
      printf 'y\n'
      printf 'y\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-alpha" \
      TEST_SCANNER_NEXT_LINE="next step: 4.1 (Initialize and Enrich Business Requirements Structuring)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Phase 4.1 (BR Enrichment Part 1) script 1/2"
  assert_contains "$out" "Phase 4.1 (BR Enrichment Part 1) script 2/2"
  assert_contains "$out" "Phase 4.2 (BR Enrichment Part 2) script 1/2"
  assert_contains "$out" "Phase 4.2 (BR Enrichment Part 2) script 2/2"
  assert_not_contains "$out" "Project init is incomplete"
  assert_contains "$out" "Execution stopped: user denied phase progression at 5."

  local expected_log
  expected_log=$'feature_br_scaffold.sh --path projects/project-a\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_scan_repo_for_br.sh --feature_path projects/project-a/feature-alpha\nfeature_task_to_br.sh --feature_path projects/project-a/feature-alpha\nfeature_user_br_clarification.sh --feature_path projects/project-a/feature-alpha\nfeature_br_check_ears_readiness.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_type_a_phase_4_1_skips_repo_scan_and_runs_task_to_br() {
  local asdlc_root="$TMP_ROOT/asdlc-type-a-skip-scan"
  local log_file="$TMP_ROOT/asdlc-type-a-skip-scan.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  cat >"$asdlc_root/projects/project-a/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_type_code: "A"
steps: []
OUT

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 4.1 (Scan repo and apply task-to-BR update)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Skipping repo scan in phase 4.1 for type A project: repo scan not applicable."
  assert_contains "$out" "Phase 4.1 (BR Enrichment Part 1) script 1/1"
  assert_contains "$out" "Execution stopped: user denied phase progression at 4.2."
  assert_not_contains "$out" "Phase 4.1 (BR Enrichment Part 1) script 2/2"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_contains "$log_content" "feature_task_to_br.sh --feature_path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_scan_repo_for_br.sh --feature_path projects/project-a/feature-alpha"
}

test_default_resume_uses_scanner_next_step() {
  local asdlc_root="$TMP_ROOT/asdlc-default-resume"
  local log_file="$TMP_ROOT/asdlc-default-resume.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 8.3 (Implementation Plan)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Loaded saved feature_path cache: projects/project-a/feature-alpha"
  assert_contains "$out" "Project feature options:"
  assert_contains "$out" "Selected unfinished feature: projects/project-a/feature-alpha"
  assert_contains "$out" "Optional phase declined at 8.4; skipping."
  assert_contains "$out" "Execution finished: no remaining required phases after declined optional phase 8.4."

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_contains "$log_content" "feature_implementation_plan.sh --feature_path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
}

test_scanner_step_1_1_fails_with_stack_blueprint_guidance() {
  local asdlc_root="$TMP_ROOT/asdlc-step-1-1-prereq"
  local log_file="$TMP_ROOT/asdlc-step-1-1-prereq.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 1.1 (Define Project Stack Blueprints For Active Classes)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project init is incomplete: scanner returned step 1.1 (Define Project Stack Blueprints For Active Classes)."
  assert_contains "$out" "project_add_feature_e2e.sh starts at feature step 3"
  assert_contains "$out" ".commands/init_project_stack_blueprints.sh --path projects/project-a"
  assert_not_contains "$out" "Unable to map scanner next step"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_scan_repo_for_br.sh --feature_path projects/project-a/feature-alpha"
}

test_scanner_step_2_fails_with_common_contract_guidance() {
  local asdlc_root="$TMP_ROOT/asdlc-step-2-prereq"
  local log_file="$TMP_ROOT/asdlc-step-2-prereq.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 2 (Create Cross-Repository Contract Definition For This Project)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project init is incomplete: scanner returned step 2 (Create Cross-Repository Contract Definition For This Project)."
  assert_contains "$out" ".commands/init_common_contract_definition.sh --path projects/project-a"
  assert_not_contains "$out" "Unable to map scanner next step"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_scan_repo_for_br.sh --feature_path projects/project-a/feature-alpha"
}

test_future_pre_feature_scanner_step_fails_with_generic_guidance() {
  local asdlc_root="$TMP_ROOT/asdlc-step-2-10-prereq"
  local log_file="$TMP_ROOT/asdlc-step-2-10-prereq.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 2.10 (Future Project Prerequisite)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project init is incomplete: scanner returned step 2.10 (Future Project Prerequisite)."
  assert_contains "$out" "Complete scanner-reported project step 2.10 before rerunning project_add_feature_e2e.sh."
  assert_not_contains "$out" ".commands/init_common_contract_definition.sh"
  assert_not_contains "$out" "Unable to map scanner next step"
}

test_unknown_later_scanner_step_keeps_unmapped_error() {
  local asdlc_root="$TMP_ROOT/asdlc-step-9-unmapped"
  local log_file="$TMP_ROOT/asdlc-step-9-unmapped.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 9.1 (Unknown Future Feature Step)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Unable to map scanner next step '9.1 (Unknown Future Feature Step)' to orchestrator phase."
  assert_not_contains "$out" "Project init is incomplete"
}

test_resume_override_starts_from_requested_phase() {
  local asdlc_root="$TMP_ROOT/asdlc-resume-override"
  local log_file="$TMP_ROOT/asdlc-resume-override.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 8.3 (Implementation Plan)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a --resume 4.2 2>&1
  )"

  assert_contains "$out" "Loaded saved feature_path cache: projects/project-a/feature-alpha"
  assert_contains "$out" "Selected unfinished feature: projects/project-a/feature-alpha"
  assert_contains "$out" "Execution stopped: user denied phase progression at 5."

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_user_br_clarification.sh --feature_path projects/project-a/feature-alpha\nfeature_br_check_ears_readiness.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_decline_optional_step_skips_to_next_required_step() {
  local asdlc_root="$TMP_ROOT/asdlc-optional-skip"
  local log_file="$TMP_ROOT/asdlc-optional-skip.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 5.1 ((optional) requirement_ears extra review)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Optional phase declined at 5.1; skipping."
  assert_contains "$out" "Phase 6 (Feature Contract Delta) script 1/1"
  assert_contains "$out" "Execution stopped: user denied phase progression at 6."

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_requirements_ears_review.sh --feature_path projects/project-a/feature-alpha"
  assert_not_contains "$log_content" "feature_contract_delta.sh --feature_path projects/project-a/feature-alpha"
}

test_phase7_repo_loop_tracks_completed_classes_until_option_three() {
  local asdlc_root="$TMP_ROOT/asdlc-phase7-loop"
  local log_file="$TMP_ROOT/asdlc-phase7-loop.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  cat >"$asdlc_root/projects/project-a/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_classes:
    - backend
    - frontend
steps: []
OUT

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf '1\n'
      printf 'backend\n'
      printf '1\n'
      printf 'frontend\n'
      printf '3\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 7 (Analyze Repos And Prepare Repo Execution Context)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Phase 7 class loop status for feature: projects/project-a/feature-alpha"
  assert_contains "$out" "Phase 7 options:"
  assert_contains "$out" "3) contract delta finished lets move forward"
  assert_contains "$out" "Already picked/completed classes: backend, frontend"
  assert_contains "$out" "Pending classes: none"
  assert_contains "$out" "Optional phase declined at 7.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_repo_surface_and_exec_context.sh --feature_path projects/project-a/feature-alpha\nfeature_repo_surface_and_exec_context.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_phase7_option_three_proceeds_with_pending_classes() {
  local asdlc_root="$TMP_ROOT/asdlc-phase7-pending"
  local log_file="$TMP_ROOT/asdlc-phase7-pending.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  cat >"$asdlc_root/projects/project-a/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_classes:
    - backend
    - frontend
steps: []
OUT

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf '1\n'
      printf 'backend\n'
      printf '3\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 7 (Analyze Repos And Prepare Repo Execution Context)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Proceeding with pending classes: frontend"
  assert_contains "$out" "Optional phase declined at 7.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_repo_surface_and_exec_context.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_step8_scanner_resume_starts_at_technical_requirements() {
  local asdlc_root="$TMP_ROOT/asdlc-phase8-resume"
  local log_file="$TMP_ROOT/asdlc-phase8-resume.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 8 (Create Feature-Scoped Technical Requirements)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Phase 8 (Create Feature-Scoped Technical Requirements)"
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."
  assert_not_contains "$out" "Phase 7 class loop status"

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_resume_8_runs_technical_requirements_directly() {
  local asdlc_root="$TMP_ROOT/asdlc-resume-8"
  local log_file="$TMP_ROOT/asdlc-resume-8.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 7 (Analyze Repos And Prepare Repo Execution Context)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a --resume 8 2>&1
  )"

  assert_contains "$out" "Phase 8 (Create Feature-Scoped Technical Requirements)"
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."
  assert_not_contains "$out" "Phase 7 class loop status"

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_technical_requirements.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_after_step8_orchestrator_does_not_reopen_optional_step_7_1() {
  local asdlc_root="$TMP_ROOT/asdlc-after-step8-no-7-1"
  local log_file="$TMP_ROOT/asdlc-after-step8-no-7-1.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_NEXT_LINE="next step: 8.1 (Create Implementation Slice Planning Artifact)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Phase 8.1 (Implementation Slices)"
  assert_contains "$out" "Execution stopped: user denied phase progression at 8.1."
  assert_not_contains "$out" "Phase 7.1 (Optional MCP Placeholder Enrichment)"

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_required_phase_failure_stops_run_with_restart_guidance() {
  local asdlc_root="$TMP_ROOT/asdlc-phase-failure"
  local log_file="$TMP_ROOT/asdlc-phase-failure.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_FAIL_SCRIPT="feature_contract_delta.sh" TEST_SCANNER_NEXT_LINE="next step: 6 (Define Feature Contract Delta)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "simulated failure from feature_contract_delta.sh"
  assert_contains "$out" "Execution stopped: phase 6 failed while running .commands/feature_contract_delta.sh (exit 17)."
  assert_contains "$out" "Fix the error above and restart the orchestrator. It will continue from the correct step:"
  assert_contains "$out" ".commands/project_add_feature_e2e.sh --path projects/project-a --resume 6"

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_contract_delta.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_phase7_failure_stops_before_later_phases_with_restart_guidance() {
  local asdlc_root="$TMP_ROOT/asdlc-phase7-failure"
  local log_file="$TMP_ROOT/asdlc-phase7-failure.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf '1\n'
      printf 'backend\n'
    } | TEST_LOG_FILE="$log_file" TEST_FAIL_SCRIPT="feature_repo_surface_and_exec_context.sh" TEST_SCANNER_NEXT_LINE="next step: 7 (Analyze Repos And Prepare Repo Execution Context)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "simulated failure from feature_repo_surface_and_exec_context.sh"
  assert_contains "$out" "Execution stopped: phase 7 failed while running .commands/feature_repo_surface_and_exec_context.sh (exit 17)."
  assert_contains "$out" ".commands/project_add_feature_e2e.sh --path projects/project-a --resume 7"

  local expected_log
  expected_log=$'init_progress_scanner.sh --path projects/project-a/feature-alpha\ninit_progress_scanner.sh --path projects/project-a/feature-alpha\nfeature_repo_surface_and_exec_context.sh --feature_path projects/project-a/feature-alpha'
  assert_equal "$expected_log" "$(read_log "$log_file")"
}

test_continue_flow_lists_only_unfinished_features_and_uses_selected_target() {
  local asdlc_root="$TMP_ROOT/asdlc-continue-select"
  local log_file="$TMP_ROOT/asdlc-continue-select.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  mkdir -p "$asdlc_root/projects/project-a/feature-beta"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local scanner_map=""
  scanner_map=$'projects/project-a/feature-alpha=next step: none\nprojects/project-a/feature-beta=next step: 8.3 (Implementation Plan)'

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_RESPONSE_MAP="$scanner_map" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Unfinished features:"
  assert_contains "$out" "projects/project-a/feature-beta [next step: 8.3 (Implementation Plan)]"
  assert_not_contains "$out" "projects/project-a/feature-alpha [next step:"
  assert_contains "$out" "Selected unfinished feature: projects/project-a/feature-beta"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-beta"
  assert_contains "$log_content" "feature_implementation_plan.sh --feature_path projects/project-a/feature-beta"
  assert_not_contains "$log_content" "feature_implementation_plan.sh --feature_path projects/project-a/feature-alpha"
}

test_new_feature_choice_runs_scaffold_even_when_unfinished_features_exist() {
  local asdlc_root="$TMP_ROOT/asdlc-new-choice"
  local log_file="$TMP_ROOT/asdlc-new-choice.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"

  local scanner_map=""
  scanner_map=$'projects/project-a/feature-alpha=next step: 6 (Define Feature Contract Delta)\nprojects/project-a/feature-gamma=next step: none'

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '1\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_RESPONSE_MAP="$scanner_map" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-gamma" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Project feature options:"
  assert_contains "$out" "Starting a new feature under project: projects/project-a"
  assert_contains "$out" "Saved feature_path: projects/project-a/feature-gamma"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-alpha"
  assert_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-gamma"
}

test_stale_saved_feature_path_cache_is_ignored() {
  local asdlc_root="$TMP_ROOT/asdlc-stale-cache"
  local log_file="$TMP_ROOT/asdlc-stale-cache.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  printf 'feature_path=projects/project-a/feature-missing\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-delta" TEST_SCANNER_NEXT_LINE="next step: none" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Ignoring stale saved feature_path cache: projects/project-a/feature-missing"
  assert_contains "$out" "Examined project features for: projects/project-a"
  assert_contains "$out" "No existing feature folders were found for this project."
  assert_contains "$out" "No unfinished features are available to continue."
  assert_contains "$out" "Would you like to start a new feature? Confirm the scaffold step below."
  assert_contains "$out" "Saved feature_path: projects/project-a/feature-delta"

  local log_content
  log_content="$(read_log "$log_file")"
  assert_contains "$log_content" "feature_br_scaffold.sh --path projects/project-a"
  assert_contains "$log_content" "init_progress_scanner.sh --path projects/project-a/feature-delta"
}

test_completed_cached_feature_prints_friendly_new_feature_message() {
  local asdlc_root="$TMP_ROOT/asdlc-completed-cache"
  local log_file="$TMP_ROOT/asdlc-completed-cache.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local scanner_map=""
  scanner_map=$'projects/project-a/feature-alpha=next step: none\nprojects/project-a/feature-zeta=next step: none'

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" TEST_SCANNER_RESPONSE_MAP="$scanner_map" TEST_SCAFFOLD_FEATURE_REL="projects/project-a/feature-zeta" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Loaded saved feature_path cache: projects/project-a/feature-alpha"
  assert_contains "$out" "Examined project features for: projects/project-a"
  assert_contains "$out" "Last selected feature is already complete: projects/project-a/feature-alpha"
  assert_contains "$out" "No unfinished features are available to continue."
  assert_contains "$out" "Would you like to start a new feature? Confirm the scaffold step below."
  assert_contains "$out" "Saved feature_path: projects/project-a/feature-zeta"
}

test_optional_step_7_1_can_be_declined_without_blocking_later_required_phases() {
  local asdlc_root="$TMP_ROOT/asdlc-7-1-optional"
  local log_file="$TMP_ROOT/asdlc-7-1-optional.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' \
    >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'    # continue existing feature
      printf '1\n'    # select feature 1
      printf 'n\n'    # decline optional step 7.1
      printf 'n\n'    # decline step 8
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 7.1 ((optional) MCP placeholder enrichment)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Optional phase declined at 7.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."

  local log_content
  log_content="$(read_log "$log_file")"
  # Enrichment script must NOT have run
  assert_not_contains "$log_content" "feature_surface_map_mcp_placeholder_enrichment.sh"
  # Step 8 confirmation was reached, proving 7.1 did not block progression
  assert_not_contains "$log_content" "feature_technical_requirements.sh"
}

test_optional_step_7_1_runs_when_accepted_then_continues_to_next_required_phase() {
  local asdlc_root="$TMP_ROOT/asdlc-7-1-accepted"
  local log_file="$TMP_ROOT/asdlc-7-1-accepted.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' \
    >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'    # continue existing feature
      printf '1\n'    # select feature 1
      printf 'y\n'    # accept optional step 7.1
      printf 'n\n'    # decline step 8
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 7.1 ((optional) MCP placeholder enrichment)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  local log_content
  log_content="$(read_log "$log_file")"
  # Enrichment script ran
  assert_contains "$log_content" "feature_surface_map_mcp_placeholder_enrichment.sh"
  # Step 8 confirmation was reached after step 7.1 ran
  assert_contains "$out" "Phase 8 (Create Feature-Scoped Technical Requirements)"
}

test_checkpoint_before_5_1_commits_dirty_workspace() {
  local asdlc_root="$TMP_ROOT/asdlc-checkpoint-before-5-1"
  local log_file="$TMP_ROOT/asdlc-checkpoint-before-5-1.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  setup_git_repo "$asdlc_root"
  printf '# dirty ears content\n' >"$asdlc_root/projects/project-a/feature-alpha/requirements_ears.md"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 5.1 ((optional) requirement_ears extra review)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Checkpoint commit created: Checkpoint: before step 5.1 (EARS review)"
  assert_contains "$out" "Optional phase declined at 5.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 6."

  local git_log
  git_log="$(git -C "$asdlc_root" log --format=%s)"
  assert_contains "$git_log" "Checkpoint: before step 5.1 (EARS review)"
}

test_checkpoint_before_7_1_logs_notice_when_workspace_is_clean() {
  local asdlc_root="$TMP_ROOT/asdlc-checkpoint-before-7-1-clean"
  local log_file="$TMP_ROOT/asdlc-checkpoint-before-7-1-clean.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  setup_git_repo "$asdlc_root"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 7.1 ((optional) MCP placeholder enrichment)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Checkpoint commit notice (before step 7.1 (MCP enrichment)): git commit exited 1; continuing without checkpoint."
  assert_contains "$out" "Optional phase declined at 7.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 8."
}

test_checkpoint_before_and_after_8_4_commit_boundary_state() {
  local asdlc_root="$TMP_ROOT/asdlc-checkpoint-around-8-4"
  local log_file="$TMP_ROOT/asdlc-checkpoint-around-8-4.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"
  setup_git_repo "$asdlc_root"
  printf '# pending implementation plan\n' >"$asdlc_root/projects/project-a/feature-alpha/implementation_plan.md"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'y\n'
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 8.4 ((optional) implementation plan semantic review)" \
      TEST_SCRIPT_TOUCH_MAP="feature_implementation_plan_semantic_review.sh=projects/project-a/feature-alpha/semantic_review.md" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Checkpoint commit created: Checkpoint: before step 8.4 (semantic review)"
  assert_contains "$out" "Checkpoint commit created: Checkpoint: after step 8.4 (semantic review)"
  assert_contains "$out" "Execution finished: reached end of configured phase map."

  local git_log
  git_log="$(git -C "$asdlc_root" log --format=%s)"
  assert_contains "$git_log" "Checkpoint: after step 8.4 (semantic review)"
  assert_contains "$git_log" "Checkpoint: before step 8.4 (semantic review)"
}

test_checkpoint_helper_skips_non_repo_workspace() {
  local asdlc_root="$TMP_ROOT/asdlc-checkpoint-non-repo"
  local log_file="$TMP_ROOT/asdlc-checkpoint-non-repo.log"
  mkdir -p "$asdlc_root"
  setup_workspace "$asdlc_root"

  mkdir -p "$asdlc_root/projects/project-a/feature-alpha"
  printf 'feature_path=projects/project-a/feature-alpha\n' >"$asdlc_root/projects/project-a/.project_add_feature_e2e_state.env"

  local out=""
  out="$(
    cd "$asdlc_root" &&
    {
      printf '2\n'
      printf '1\n'
      printf 'n\n'
      printf 'n\n'
    } | TEST_LOG_FILE="$log_file" \
      TEST_SCANNER_NEXT_LINE="next step: 5.1 ((optional) requirement_ears extra review)" \
      .commands/project_add_feature_e2e.sh --path projects/project-a 2>&1
  )"

  assert_contains "$out" "Checkpoint commit skipped (before step 5.1 (EARS review)): runtime root is not a git repository."
  assert_contains "$out" "Optional phase declined at 5.1; skipping."
  assert_contains "$out" "Execution stopped: user denied phase progression at 6."
}

test_deferred_class_prompt_yes_attaches_planned_repo_with_policy_c
test_deferred_class_prompt_no_leaves_class_deferred
test_deferred_class_prompt_alternate_path_attaches_alternate_repo
test_deferred_class_prompt_invalid_alternate_path_reprompts_once_then_attaches
test_deferred_class_with_nonexistent_planned_repo_path_stays_silent
test_deferred_class_attach_skips_reconciliation_when_marker_exists
test_ready_class_without_reconciliation_marker_retries_on_next_run
test_alternate_attach_reconciliation_failure_does_not_prompt_for_another_path
test_without_path_uses_only_project_in_workspace
test_without_path_prompts_for_project_when_multiple_exist
test_without_path_can_finish_when_multiple_projects_exist
test_scaffold_first_run_persists_feature_path_and_calls_scanner
test_scaffold_path_capture_accepts_prefixed_created_line
test_scaffold_path_capture_falls_back_to_updated_line
test_split_4_1_and_4_2_execute_in_order_with_messages
test_type_a_phase_4_1_skips_repo_scan_and_runs_task_to_br
test_default_resume_uses_scanner_next_step
test_scanner_step_1_1_fails_with_stack_blueprint_guidance
test_scanner_step_2_fails_with_common_contract_guidance
test_future_pre_feature_scanner_step_fails_with_generic_guidance
test_unknown_later_scanner_step_keeps_unmapped_error
test_resume_override_starts_from_requested_phase
test_decline_optional_step_skips_to_next_required_step
test_phase7_repo_loop_tracks_completed_classes_until_option_three
test_phase7_option_three_proceeds_with_pending_classes
test_step8_scanner_resume_starts_at_technical_requirements
test_resume_8_runs_technical_requirements_directly
test_after_step8_orchestrator_does_not_reopen_optional_step_7_1
test_required_phase_failure_stops_run_with_restart_guidance
test_phase7_failure_stops_before_later_phases_with_restart_guidance
test_continue_flow_lists_only_unfinished_features_and_uses_selected_target
test_new_feature_choice_runs_scaffold_even_when_unfinished_features_exist
test_stale_saved_feature_path_cache_is_ignored
test_completed_cached_feature_prints_friendly_new_feature_message
test_optional_step_7_1_can_be_declined_without_blocking_later_required_phases
test_optional_step_7_1_runs_when_accepted_then_continues_to_next_required_phase
test_checkpoint_before_5_1_commits_dirty_workspace
test_checkpoint_before_7_1_logs_notice_when_workspace_is_clean
test_checkpoint_before_and_after_8_4_commit_boundary_state
test_checkpoint_helper_skips_non_repo_workspace

echo "All project_add_feature_e2e tests passed."
